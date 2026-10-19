import hashlib
import json
import os
import secrets
import threading
import time
import uuid
from collections import OrderedDict
from contextlib import asynccontextmanager
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb
from psycopg_pool import ConnectionPool

from models import (
    ALPHABET,
    Conflict,
    ConflictEntry,
    CreatedAccount,
    LoginRequest,
    Message,
    Prices,
    PublishRequest,
    Row,
    Session,
    SyncRequest,
    SyncResult,
)

pool: ConnectionPool | None = None
bearer = HTTPBearer(auto_error=False)
attempts: OrderedDict = OrderedDict()
attempt_lock = threading.Lock()


def digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def recovery_hash(code: str) -> str:
    # 난수 코드의 160비트 비밀은 원문 대신 목적별 SHA-256 해시로 보관한다.
    return digest("howmuch:recovery:v1:identity:" + code)


@asynccontextmanager
async def lifespan(app: FastAPI):
    global pool
    pool = ConnectionPool(
        os.environ["DATABASE_URL"],
        min_size=1,
        max_size=4,
        kwargs={
            "row_factory": dict_row,
            "options": "-c statement_timeout=5000 -c lock_timeout=3000",
        },
        open=False,
        timeout=5,
    )
    pool.open()
    pool.wait(timeout=20)
    with pool.connection() as conn:
        conn.execute(Path(__file__).with_name("schema.sql").read_text())
    yield
    pool.close()


app = FastAPI(
    title="얼마였지 동기화 API",
    version="1.0.0",
    lifespan=lifespan,
    root_path=os.getenv("ROOT_PATH", ""),
    description="복구 코드는 최초 한 번만 표시됩니다. Bearer 세션으로 자신의 기록만 동기화합니다.",
    responses={
        401: {"model": Message, "description": "인증 실패"},
        422: {"model": Message, "description": "입력 오류"},
        429: {"model": Message, "description": "요청 제한"},
    },
)


@app.exception_handler(RequestValidationError)
async def validation_error(request: Request, exc: RequestValidationError):
    # 인증 입력을 응답이나 로그에 되돌려 보내지 않는다.
    return JSONResponse(
        status_code=422, content={"detail": "입력 형식과 허용 범위를 확인해주세요."}
    )


@app.middleware("http")
async def no_secret_cache(request: Request, call_next):
    response = await call_next(request)
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response


class BodyLimit:
    """Content-Length가 없는 요청에도 1MiB 한도를 적용한다."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        body = bytearray()
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            if len(body) + len(message.get("body", b"")) > 1_048_576:
                response = JSONResponse(
                    status_code=413, content={"detail": "요청 데이터가 너무 큽니다."}
                )
                await response(scope, receive, send)
                return
            body.extend(message.get("body", b""))
            if not message.get("more_body", False):
                break

        async def buffered_receive():
            return {"type": "http.request", "body": bytes(body), "more_body": False}

        await self.app(scope, buffered_receive, send)


app.add_middleware(BodyLimit)


def rate_limit(key: str, maximum: int, period: int):
    # ponytail: 한 API 프로세스의 제한이다. 다중 replica 전환 시 게이트웨이 제한으로 옮긴다.
    now = time.monotonic()
    with attempt_lock:
        count, reset = attempts.pop(key, (0, now + period))
        if now >= reset:
            count, reset = 0, now + period
        attempts[key] = (count + 1, reset)
        while len(attempts) > 2048:
            attempts.popitem(last=False)
        if count >= maximum:
            raise HTTPException(429, "요청이 많습니다. 잠시 후 다시 시도해주세요.")


def auth(credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]) -> dict:
    if credentials is None or len(credentials.credentials) > 200:
        raise HTTPException(401, "복구 코드로 기록을 연결해주세요.")
    token_hash = digest(credentials.credentials)
    with pool.connection() as conn:
        session = conn.execute(
            "SELECT account_id, token_hash FROM sessions WHERE token_hash=%s AND expires_at>now()",
            (token_hash,),
        ).fetchone()
    if session is None:
        raise HTTPException(401, "세션이 만료되었습니다. 복구 코드로 다시 연결해주세요.")
    rate_limit("account:" + str(session["account_id"]), 120, 60)
    return session


Auth = Annotated[dict, Depends(auth)]


def new_session(conn, account_id) -> Session:
    token = secrets.token_urlsafe(32)
    expires = datetime.now(UTC) + timedelta(days=365)
    conn.execute("DELETE FROM sessions WHERE expires_at<=now()")
    # 한 계정의 유효 세션은 최근 20개만 유지한다.
    conn.execute(
        """DELETE FROM sessions WHERE account_id=%s AND token_hash IN (
        SELECT token_hash FROM sessions WHERE account_id=%s ORDER BY expires_at DESC OFFSET 19)
        """,
        (account_id, account_id),
    )
    conn.execute("INSERT INTO sessions VALUES (%s,%s,%s)", (digest(token), account_id, expires))
    return Session(accountId=str(account_id), token=token, expiresAt=expires.isoformat())


@app.get("/health", response_model=Message, tags=["운영"])
def health():
    return Message(detail="ok")


@app.get("/ready", response_model=Message, tags=["운영"])
def ready():
    with pool.connection() as conn:
        conn.execute("SELECT 1")
    return Message(detail="ready")


@app.post(
    "/v1/accounts",
    response_model=CreatedAccount,
    status_code=201,
    tags=["계정"],
    summary="새 복구 코드 계정 발급",
)
def create_account(request: Request):
    rate_limit("create:global", 100, 3600)
    rate_limit("create:" + request.client.host, 10, 60)
    code = "".join(secrets.choice(ALPHABET) for _ in range(32))
    account_id = uuid.uuid4()
    with pool.connection() as conn:
        conn.execute(
            "INSERT INTO accounts(id,recovery_hash) VALUES (%s,%s)",
            (account_id, recovery_hash(code)),
        )
        session = new_session(conn, account_id)
    return CreatedAccount(
        **session.model_dump(), recoveryCode="-".join(code[i : i + 4] for i in range(0, 32, 4))
    )


@app.post(
    "/v1/sessions", response_model=Session, tags=["계정"], summary="복구 코드로 기존 계정 복원"
)
def login(body: LoginRequest, request: Request):
    rate_limit("login:" + request.client.host, 30, 60)
    with pool.connection() as conn:
        account = conn.execute(
            "SELECT id FROM accounts WHERE recovery_hash=%s FOR UPDATE",
            (recovery_hash(body.recoveryCode),),
        ).fetchone()
        if account is None:
            raise HTTPException(401, "복구 코드를 확인해주세요.")
        return new_session(conn, account["id"])


@app.delete("/v1/session", response_model=Message, tags=["계정"], summary="현재 기기의 세션 폐기")
def logout(session: Auth):
    with pool.connection() as conn:
        conn.execute("DELETE FROM sessions WHERE token_hash=%s", (session["token_hash"],))
    return Message(detail="로그아웃했습니다.")


def synced(row: Row) -> Row:
    return row.model_copy(
        update={"pending": False, "baseRevision": row.revision, "group": row.revision}
    )


def reconcile(server: list[Row], local: list[Row]) -> SyncResult:
    rows = {row.id: synced(row) for row in server}
    groups = {}
    conflicts = []
    for row in local:
        if row.pending:
            groups.setdefault(row.group or row.revision, []).append(row)
    for group, changes in groups.items():
        collision = any(
            (rows[row.id].revision if row.id in rows else None)
            not in (row.revision, row.baseRevision)
            for row in changes
        )
        if collision:
            conflicts.append(
                Conflict(
                    group=group,
                    entries=[ConflictEntry(local=row, remote=rows.get(row.id)) for row in changes],
                )
            )
        else:
            for row in changes:
                rows[row.id] = synced(row)
    return SyncResult(rows=list(rows.values()), conflicts=conflicts)


def product_key(identity: str) -> str:
    identity = re_normalize(identity)
    # Dart의 UTF-16 codeUnits 규칙과 같아 이모지가 포함된 제품도 같은 키를 갖는다.
    encoded = identity.encode("utf-16-be")
    return "v2-" + encoded.hex() if identity else "other"


def re_normalize(value: str) -> str:
    return "".join(value.lower().split())


def refresh_prices(conn, account_id, rows: list[Row]):
    # 공유 자료는 인증된 계정의 저장 기록에서만 만든다. 계정·메모·영수증 ID는 공개하지 않는다.
    conn.execute("DELETE FROM shared_prices WHERE account_id=%s", (account_id,))
    for row in rows:
        purchase = row.purchase
        if (
            row.deleted
            or purchase is None
            or not purchase.share
            or purchase.setParentId  # [OCR 추가] 세트 구성품을 단독 공유 가격으로 공개하지 않는다.
            or not purchase.registeredAt
            or purchase.spec is None
            or not purchase.spec.comparable()
        ):
            continue
        public = purchase.model_dump()
        public.update(receiptId="", itemId="", productKey=product_key(purchase.spec.identity))
        record = {
            "id": digest(str(account_id) + ":" + row.id),
            "title": purchase.spec.identity,
            "purchase": public,
        }
        conn.execute(
            "INSERT INTO shared_prices VALUES (%s,%s,%s,%s)",
            (account_id, row.id, public["productKey"], Jsonb(record)),
        )


@app.post("/v1/sync", response_model=SyncResult, tags=["기록"], summary="기록 교환과 충돌 확인")
def sync(body: SyncRequest, session: Auth):
    with pool.connection() as conn:
        # 같은 계정의 두 기기 요청은 행 잠금과 한 트랜잭션으로 순서대로 반영한다.
        account = conn.execute(
            "SELECT rows FROM accounts WHERE id=%s FOR UPDATE", (session["account_id"],)
        ).fetchone()
        before = [Row.model_validate(row) for row in account["rows"]]
        result = reconcile(before, body.rows)
        saved = [
            row.model_dump(exclude={"pending", "baseRevision", "group"}, exclude_none=True)
            for row in result.rows
        ]
        if len(saved) > 1000 or len(json.dumps(saved, ensure_ascii=False).encode()) > 200_000:
            raise HTTPException(413, "계정 기록이 너무 큽니다. 기기 기록은 유지됩니다.")
        if saved != account["rows"]:
            conn.execute(
                "UPDATE accounts SET rows=%s WHERE id=%s", (Jsonb(saved), session["account_id"])
            )
            refresh_prices(conn, session["account_id"], result.rows)
        return result


@app.post(
    "/v1/prices/publish",
    response_model=Message,
    tags=["가격"],
    summary="저장된 구매 기록 공유 재시도",
)
def publish(body: PublishRequest, session: Auth):
    with pool.connection() as conn:
        account = conn.execute(
            "SELECT rows FROM accounts WHERE id=%s FOR UPDATE", (session["account_id"],)
        ).fetchone()
        rows = [Row.model_validate(row) for row in account["rows"]]
        if not set(body.rowIds).issubset({row.id for row in rows}):
            raise HTTPException(404, "자신의 저장된 기록만 공유할 수 있습니다.")
        refresh_prices(conn, session["account_id"], rows)
    return Message(detail="공유 설정을 반영했습니다.")


@app.get(
    "/v1/prices", response_model=Prices, tags=["가격"], summary="다른 계정의 익명 제품 가격 조회"
)
def prices(session: Auth, productKey: Annotated[str, Query(min_length=1, max_length=500)]):
    with pool.connection() as conn:
        records = conn.execute(
            """SELECT record FROM shared_prices
            WHERE product_key=%s AND account_id<>%s
            ORDER BY record->'purchase'->>'purchasedOn' DESC,
                     record->'purchase'->>'registeredAt' DESC LIMIT 200""",
            (productKey, session["account_id"]),
        ).fetchall()
    return Prices(records=[row["record"] for row in records])
