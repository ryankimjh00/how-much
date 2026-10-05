"""실제 HTTPS와 PostgreSQL 재시작을 검증하고 이 실행의 시험 계정만 제거한다."""

import subprocess
import time
import uuid

import httpx

URL = "https://howmuch.monithub.org"
accounts = []


def call(client, method, path, session=None, **kwargs):
    headers = {"Authorization": "Bearer " + session["token"]} if session else {}
    response = client.request(method, path, headers=headers, **kwargs)
    assert response.status_code < 300, f"{path}: HTTP {response.status_code}"
    return response.json()


try:
    with httpx.Client(base_url=URL, timeout=30) as client:
        first = call(client, "POST", "/v1/accounts")
        accounts.append(first["accountId"])
        second = call(client, "POST", "/v1/accounts")
        accounts.append(second["accountId"])
        restored = call(
            client,
            "POST",
            "/v1/sessions",
            json={"recoveryCode": first["recoveryCode"].lower().replace("-", " ")},
        )
        assert restored["accountId"] == first["accountId"]
        row = {
            "id": "cluster-smoke",
            "title": "시험 기록",
            "revision": "1791154800000000:smoke",
            "pending": True,
            "baseRevision": None,
            "group": "",
            "completed": False,
        }
        call(client, "POST", "/v1/sync", first, json={"rows": [row]})
        assert call(client, "POST", "/v1/sync", second, json={"rows": []})["rows"] == []
        assert client.post("/v1/sessions", json={"recoveryCode": "A" * 32}).status_code == 401
        assert client.post("/v1/sync", json={"rows": []}).status_code == 401
        print("HTTPS 인증·복원·계정 분리 통과")
        subprocess.run(
            ["kubectl", "-n", "howmuch", "rollout", "restart", "statefulset/postgres"], check=True
        )
        subprocess.run(
            [
                "kubectl",
                "-n",
                "howmuch",
                "rollout",
                "status",
                "statefulset/postgres",
                "--timeout=120s",
            ],
            check=True,
        )
        for _ in range(20):
            if client.get("/ready").status_code == 200:
                break
            time.sleep(2)
        fetched = call(client, "POST", "/v1/sync", restored, json={"rows": []})["rows"][0]
        assert fetched["title"] == row["title"]
        updated = {
            **fetched,
            "title": "두 번째 수정",
            "revision": "1791154800000001:smoke",
            "baseRevision": fetched["revision"],
            "pending": True,
        }
        call(client, "POST", "/v1/sync", restored, json={"rows": [updated]})
        stale = {**updated, "title": "첫 번째 수정", "revision": "1791154800000002:smoke"}
        conflict = call(client, "POST", "/v1/sync", first, json={"rows": [stale]})["conflicts"][0]
        assert conflict["entries"][0]["remote"]["title"] == "두 번째 수정"
        assert conflict["entries"][0]["local"]["title"] == "첫 번째 수정"
        assert client.get("/docs").status_code == 200
        assert client.get("/openapi.json").json()["info"]["version"] == "1.0.0"
        assert client.get("https://monithub.org/").status_code == 200
        print("DB 재시작 보존·충돌·Swagger·기존 홈페이지 통과")
finally:
    for account in accounts:
        # UUID 형식을 확인한 이번 실행의 계정만 삭제한다.
        account = str(uuid.UUID(account))
        subprocess.run(
            [
                "kubectl",
                "-n",
                "howmuch",
                "exec",
                "postgres-0",
                "--",
                "psql",
                "-U",
                "howmuch",
                "-d",
                "howmuch",
                "-c",
                f"DELETE FROM accounts WHERE id='{account}'::uuid",
            ],
            check=True,
            stdout=subprocess.DEVNULL,
        )
    print("시험 계정 정리 완료")
