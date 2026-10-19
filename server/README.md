# 얼마였지 API

FastAPI + PostgreSQL 17. 기본 주소는 `https://howmuch.monithub.org`다.

- [Swagger UI](https://howmuch.monithub.org/docs)
- [운영 OpenAPI](https://howmuch.monithub.org/openapi.json), 저장소 계약: `openapi.json`
- 요청·응답 예제는 `models.py`에 정의하고 Swagger와 함께 생성한다.

## 로컬 실행과 검증

```sh
docker run --name howmuch-test-db -e POSTGRES_PASSWORD=local-test-only \
  -e POSTGRES_DB=howmuch_test -p 127.0.0.1:55432:5432 -d postgres:17-alpine
cd server
uv sync --locked
DATABASE_URL=postgresql://postgres:local-test-only@127.0.0.1:55432/howmuch_test uv run pytest -q
DATABASE_URL=postgresql://postgres:local-test-only@127.0.0.1:55432/howmuch_test uv run uvicorn main:app --port 8000 --no-access-log
```

테스트는 `127.0.0.1:55432/howmuch_test`만 비운다. 운영 DB로 실행하면 중단한다.
DB 스키마는 API 시작 때 `CREATE TABLE/INDEX IF NOT EXISTS`로 초기화한다. 이후 파괴적인 스키마 변경은 별도 마이그레이션으로 처리한다.

## 인증과 저장 계약

| 요청 | 동작 |
|---|---|
| `POST /v1/accounts` | 160비트 복구 코드와 새 계정·세션 발급, 201 |
| `POST /v1/sessions` | 코드의 소문자·공백·하이픈 정규화 후 기존 계정 복원 |
| `DELETE /v1/session` | 현재 Bearer 세션 폐기 |
| `POST /v1/sync` | `{rows:[...]}` 교환, `{rows:[...],conflicts:[...]}` 반환 |
| `POST /v1/prices/publish` | `{rowIds:[...]}`에 해당하는 자신의 저장 기록 공유 재시도 |
| `GET /v1/prices?productKey=...` | 다른 계정의 익명 비교 가격, 최대 200개 |
| `GET /health`, `GET /ready` | 프로세스 상태·DB 연결 확인 |

복구 코드는 32개 문자 `23456789ABCDEFGHJKLMNPQRSTUVWXYZ`에서 보안 난수로 뽑은 32자리다. 원문은 발급 응답에만 포함하며 DB에는 `SHA256("howmuch:recovery:v1:identity:" + 정규화한 코드)`만 남긴다. 세션은 256비트 난수이며 DB에는 SHA-256 해시만 저장한다. 만료는 365일, 계정당 최근 20개 세션이다. 잘못된 코드로는 계정을 만들지 않는다.

API는 Bearer 세션에서 계정을 결정한다. 요청에 계정 ID를 받지 않는다. 계정 행을 잠그고 그룹별 `baseRevision`을 확인해 변경·충돌·공유 해제를 한 트랜잭션으로 처리한다. 복구 코드가 유출되면 계정 접근이 가능하며 코드 교체 기능은 아직 없다.

계정 상태는 최대 1,000행·UTF-8 JSON 200,000바이트, 요청 본문은 최대 1MiB다. 삭제 기록도 한도에 포함한다. 실패하면 앱의 미전송 기록은 남는다. 공유 자료에는 계정 ID, 메모, 원본 사진, 영수증·장보기 ID를 넣지 않는다. 제품 키는 서버가 규격에서 계산하고 자신의 가격은 조회에서 제외한다.

요청 제한은 API 한 프로세스 메모리에 적용한다. 발급 전체 100회/시간·연결 출처당 10회/분, 복원 출처당 30회/분, 인증 계정당 120회/분이다. 출처는 연결 상대이며 hostNetwork 게이트웨이를 여러 사용자가 공유한다. 다중 replica 배포 전에는 게이트웨이 제한으로 옮긴다. 본문·헤더·접근 로그를 출력하지 않는다. 서버 설정에는 `DATABASE_URL`, 필요 시 프록시용 `ROOT_PATH`만 사용한다.

## 계약 갱신

```sh
uv run python - <<'PY'
import json
from main import app
with open('openapi.json', 'w') as f:
    json.dump(app.openapi(), f, ensure_ascii=False, indent=2)
    f.write('\n')
PY
uv export --locked --no-dev --no-hashes --no-emit-project --output-file requirements.txt
```

의존성은 `uv.lock`과 `requirements.txt`로 고정한다. Docker 이미지와 Kubernetes 이미지도 검증한 digest로 고정한다.

## 영수증 세트 관계

[OCR 추가] `purchase.setParentId`는 같은 영수증의 기준 구매 기록 ID다. 기본값은 빈 문자열이며 기존 구매 기록은 그대로 읽는다. 구성품의 상품명·수량·금액은 각각 보존하고 세트 가격을 임의 배분하지 않는다. 구성품은 단독 공유 가격으로 공개하지 않는다. DB의 기존 JSON 기록과 동기화 트랜잭션을 사용하므로 테이블 변경은 없다.

기준 기록 `purchase-receipt-set-parent`가 이미 동기화되어 있을 때 구성품 전송 요청(`POST /v1/sync`) 예:

```json
{
  "rows": [
    {
      "id": "purchase-receipt-set-component",
      "title": "증정 세제",
      "completed": true,
      "revision": "1791154800000000:device1",
      "pending": true,
      "baseRevision": null,
      "group": "1791154800000000:device1",
      "purchase": {
        "receiptId": "receipt-set",
        "itemId": "",
        "store": "마트",
        "purchasedOn": "2026-10-01",
        "quantity": 2,
        "total": 0,
        "setParentId": "purchase-receipt-set-parent"
      }
    }
  ]
}
```

정상 응답 예(다른 기존 행은 생략):

```json
{
  "rows": [
    {
      "id": "purchase-receipt-set-component",
      "title": "증정 세제",
      "completed": true,
      "revision": "1791154800000000:device1",
      "pending": false,
      "baseRevision": "1791154800000000:device1",
      "group": "1791154800000000:device1",
      "purchase": {
        "receiptId": "receipt-set",
        "itemId": "",
        "store": "마트",
        "purchasedOn": "2026-10-01",
        "quantity": 2,
        "total": 0,
        "setParentId": "purchase-receipt-set-parent"
      }
    }
  ],
  "conflicts": []
}
```

새 세트 필드를 전송하기 전에 이 서버 버전을 배포해야 한다. 이전 서버는 알 수 없는 필드를 거부한다. 실패한 전송은 앱의 로컬 미전송 기록을 유지한다. 이전 앱으로 세트 기록을 편집하면 관계 필드가 유실될 수 있으므로 세트 사용 기기에는 새 앱을 사용한다.

새 서버 단위 검증은 프로젝트 Python 환경에서 `python -m unittest test_receipt_sets -v`로 실행한다. DB가 없는 직렬화·계약·공유 필터 검증이며 PostgreSQL 통합 테스트와 구분한다.
