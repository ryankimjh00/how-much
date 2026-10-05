"""빈 howmuch namespace의 DB Secret을 생성한다. 기존 비밀번호는 바꾸지 않는다."""

import json
import secrets
import subprocess
from urllib.parse import quote

exists = subprocess.run(
    [
        "kubectl",
        "get",
        "secret",
        "database",
        "-n",
        "howmuch",
        "--ignore-not-found",
        "-o",
        "name",
    ],
    capture_output=True,
    check=False,
)
if exists.returncode != 0:
    raise SystemExit("DB Secret 조회 실패. 비밀번호를 변경하지 않습니다.")
if exists.stdout.strip():
    print("기존 DB Secret을 유지합니다.")
    raise SystemExit(0)
admin_password = secrets.token_urlsafe(32)
api_password = secrets.token_urlsafe(32)
secret = {
    "apiVersion": "v1",
    "kind": "Secret",
    "metadata": {"name": "database", "namespace": "howmuch"},
    "type": "Opaque",
    "stringData": {
        "password": admin_password,
        "url": f"postgresql://howmuch_api:{quote(api_password)}@postgres.howmuch.svc.cluster.local:5432/howmuch",
        "init.sql": (
            f"CREATE ROLE howmuch_api LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD '{api_password}';\n"
            "GRANT CONNECT ON DATABASE howmuch TO howmuch_api;\n"
            "GRANT USAGE, CREATE ON SCHEMA public TO howmuch_api;\n"
        ),
    },
}
# 비밀 값은 명령 인수·파일·로그 대신 kubectl의 표준 입력으로 전달한다.
subprocess.run(
    ["kubectl", "apply", "--server-side", "--field-manager=howmuch-deploy", "-f", "-"],
    input=json.dumps(secret),
    text=True,
    check=True,
)
