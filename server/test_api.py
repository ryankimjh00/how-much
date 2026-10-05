import copy
import os
from concurrent.futures import ThreadPoolExecutor

import psycopg
import pytest
from fastapi.testclient import TestClient

import main
from models import ROW_EXAMPLE, Row


@pytest.fixture
def client():
    # 테스트용 DB만 비운다. 운영 주소가 들어오면 즉시 중단한다.
    database = os.environ["DATABASE_URL"]
    assert database.endswith("/howmuch_test") and "127.0.0.1:55432" in database
    main.attempts.clear()
    with TestClient(main.app) as client:
        with psycopg.connect(database) as conn:
            conn.execute("TRUNCATE accounts CASCADE")
        yield client


def account(client):
    response = client.post("/v1/accounts")
    assert response.status_code == 201
    return response.json()


def headers(session):
    return {"Authorization": "Bearer " + session["token"]}


def sync(client, session, rows):
    return client.post("/v1/sync", headers=headers(session), json={"rows": rows})


def test_recovery_isolation_revocation_and_no_plaintext(client):
    first, second = account(client), account(client)
    code = first["recoveryCode"].lower().replace("-", " ")
    restored = client.post("/v1/sessions", json={"recoveryCode": code}).json()
    assert restored["accountId"] == first["accountId"]
    assert sync(client, first, [ROW_EXAMPLE]).status_code == 200
    assert sync(client, restored, []).json()["rows"][0]["title"] == "우유"
    assert sync(client, second, []).json()["rows"] == []
    assert client.post("/v1/sessions", json={"recoveryCode": "A" * 32}).status_code == 401
    assert client.post("/v1/sync", json={"rows": []}).status_code == 401
    with main.pool.connection() as conn:
        saved = conn.execute(
            "SELECT recovery_hash FROM accounts WHERE id=%s", (first["accountId"],)
        ).fetchone()
        tokens = conn.execute("SELECT token_hash FROM sessions").fetchall()
    assert saved["recovery_hash"] != first["recoveryCode"].replace("-", "")
    assert all(item["token_hash"] != first["token"] for item in tokens)
    assert client.delete("/v1/session", headers=headers(first)).status_code == 200
    assert sync(client, first, []).status_code == 401
    assert sync(client, restored, []).status_code == 200


def test_atomic_group_conflicts_retry_and_concurrent_requests(client):
    session = account(client)
    rows = [{**ROW_EXAMPLE, "id": "one"}, {**ROW_EXAMPLE, "id": "two"}]
    assert sync(client, session, rows).status_code == 200
    edited = [
        {
            **row,
            "title": "변경",
            "revision": "1791154800000001:device2",
            "baseRevision": row["revision"],
            "group": "batch",
        }
        for row in rows
    ]
    assert sync(client, session, edited).json()["conflicts"] == []
    # 응답이 유실되어 같은 변경을 재전송해도 충돌을 만들지 않는다.
    assert sync(client, session, edited).json()["conflicts"] == []
    collided = [{**row, "revision": "1791154800000002:device3"} for row in edited]
    result = sync(client, session, collided).json()
    assert len(result["conflicts"][0]["entries"]) == 2
    assert {row["revision"] for row in result["rows"]} == {edited[0]["revision"]}
    original = result["rows"][0]
    competing = [
        {
            **original,
            "pending": True,
            "group": "",
            "title": str(i),
            "revision": f"179115480000000{i + 3}:device",
        }
        for i in range(2)
    ]
    with ThreadPoolExecutor(2) as executor:
        results = list(executor.map(lambda row: sync(client, session, [row]).json(), competing))
    assert sorted(len(result["conflicts"]) for result in results) == [0, 1]


def test_price_privacy_unshare_and_forged_publish(client):
    first, second = account(client), account(client)
    row = copy.deepcopy(ROW_EXAMPLE)
    row["purchase"] = {
        "receiptId": "private-receipt",
        "itemId": "private-item",
        "productKey": "forged",
        "store": "마트",
        "purchasedOn": "2026-10-05",
        "quantity": 1,
        "total": 2500,
        "condition": "",
        "share": True,
        "registeredAt": "2026-10-05T10:00:00",
        "spec": {
            "identity": "서울우유",
            "volume": 1000,
            "unit": "ml",
            "packCount": 1,
            "conditionKnown": True,
            "allocated": True,
        },
    }
    assert sync(client, first, [row]).status_code == 200
    key = main.product_key("서울우유")
    result = client.get("/v1/prices", params={"productKey": key}, headers=headers(second)).json()
    assert len(result["records"]) == 1
    assert "private" not in str(result) and first["accountId"] not in str(result)
    assert result["records"][0]["id"] != row["id"]
    assert (
        client.post(
            "/v1/prices/publish", json={"rowIds": [row["id"]]}, headers=headers(second)
        ).status_code
        == 404
    )
    row.update(revision="1791154800000001:device1", baseRevision=row["revision"])
    row["purchase"]["share"] = False
    assert sync(client, first, [row]).status_code == 200
    assert (
        client.get("/v1/prices", params={"productKey": key}, headers=headers(second)).json()[
            "records"
        ]
        == []
    )


def test_validation_limits_and_swagger_examples(client):
    session = account(client)
    invalid = "private-secret"
    response = client.post("/v1/sessions", json={"recoveryCode": invalid})
    assert response.status_code == 422 and invalid not in response.text
    assert sync(client, session, [ROW_EXAMPLE, ROW_EXAMPLE]).status_code == 422
    assert sync(client, session, [{**ROW_EXAMPLE, "quantity": 0}]).status_code == 422
    assert sync(client, session, [{**ROW_EXAMPLE, "title": " "}]).status_code == 422
    assert (
        client.post(
            "/v1/sync",
            content='{"rows": []}' + " " * 1_048_576,
            headers={**headers(session), "Content-Type": "application/json"},
        ).status_code
        == 413
    )
    rows = [{**ROW_EXAMPLE, "id": str(i), "note": "한" * 120} for i in range(600)]
    assert sync(client, session, rows).status_code == 413
    assert sync(client, session, []).json()["rows"] == []
    schema = client.get("/openapi.json").json()
    for name in [
        "SyncRequest",
        "SyncResult",
        "LoginRequest",
        "Session",
        "CreatedAccount",
        "PublishRequest",
        "Prices",
        "Message",
    ]:
        assert "example" in schema["components"]["schemas"][name]
    assert client.get("/docs").status_code == 200


def test_dart_protocol_fixture_and_rate_limit(client):
    assert main.recovery_hash("23456789ABCDEFGHJKLMNPQRSTUVWXYZ") == (
        "e9bdf7fdae4d297c15e04b5f81e1a93e02b9f1acd779e6af396e9993db07f48a"
    )
    assert main.product_key(" 우유 🥛 ") == "v2-c6b0c720d83edd5b"
    for _ in range(30):
        assert client.post("/v1/sessions", json={"recoveryCode": "A" * 32}).status_code == 401
    assert client.post("/v1/sessions", json={"recoveryCode": "A" * 32}).status_code == 429
    assert Row.model_validate(ROW_EXAMPLE).title == "우유"
