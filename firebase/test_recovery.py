import hashlib
import json
import urllib.error
import urllib.request


# 로컬 에뮬레이터만 호출하므로 실제 계정이나 운영 데이터에 영향을 주지 않는다.
PROJECT = "demo-howmuch"
AUTH_URL = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:"
DB_URL = (
    f"http://127.0.0.1:8080/v1/projects/{PROJECT}"
    "/databases/(default)/documents/"
)


def request(url, data=None, token=None, method=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)


def credentials(code):
    # 앱의 v1 규칙과 동일하게 코드 표시 형식을 제거하고 용도별 해시를 만든다.
    normalized = "".join(code.upper().replace("-", "").split())

    def digest(purpose):
        source = f"howmuch:recovery:v1:{purpose}:{normalized}"
        return hashlib.sha256(source.encode()).hexdigest()

    return {
        "email": f"{digest('identity')}@recovery.howmuch.invalid",
        "password": f"Hmc!9a{digest('password')}",
        "returnSecureToken": True,
    }


def signup(code):
    status, user = request(AUTH_URL + "signUp?key=demo-key", credentials(code))
    assert status == 200, f"계정 생성 실패: HTTP {status}"
    return user


def main():
    code = "2345-6789-ABCD-EFGH-JKLM-NPQR-STUV-WXYZ"
    first = signup(code)
    status, restored = request(
        AUTH_URL + "signInWithPassword?key=demo-key",
        credentials(code.lower().replace("-", " ")),
    )
    assert status == 200, f"계정 복구 실패: HTTP {status}"
    assert restored["localId"] == first["localId"], "복구 후 UID가 달라졌습니다."

    other = signup("A" * 32)
    status, _ = request(
        AUTH_URL + "signInWithPassword?key=demo-key", credentials("B" * 32)
    )
    assert status == 400, "등록되지 않은 복구 코드가 허용되었습니다."

    # Firestore의 REST 형식으로 최소 기록을 저장하고 복구한 계정에서 읽는다.
    milk = {
        "id": {"stringValue": "milk"},
        "title": {"stringValue": "우유"},
        "revision": {"stringValue": "0000000000000001:a"},
        "completed": {"booleanValue": False},
        "deleted": {"booleanValue": False},
    }
    state = {
        "fields": {
            "version": {"integerValue": "4"},
            "rows": {"mapValue": {"fields": {"milk": {"mapValue": {"fields": milk}}}}},
        }
    }
    url = DB_URL + f"accounts/{first['localId']}/state/main"
    status, _ = request(url, state, first["idToken"], "PATCH")
    assert status == 200, f"기록 저장 실패: HTTP {status}"

    status, result = request(url, token=restored["idToken"])
    assert status == 200, f"복구한 기록 조회 실패: HTTP {status}"
    rows = result["fields"]["rows"]["mapValue"]["fields"]
    restored_milk = rows["milk"]["mapValue"]["fields"]
    assert restored_milk["title"]["stringValue"] == "우유"

    for token in (other["idToken"], None):
        status, _ = request(url, token=token)
        assert status == 403, "다른 계정이나 비로그인 사용자의 접근이 허용되었습니다."

    print("PASS: 복구 코드 동일 UID, 잘못된 코드 거부, 기록 저장·복원, 다른 UID·비인증 접근 거부")


if __name__ == "__main__":
    main()
