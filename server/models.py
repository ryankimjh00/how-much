import re
from datetime import date, datetime
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, field_validator

Revision = Annotated[str, Field(pattern=r"^\d{16}:[a-z0-9-]{1,100}$")]
ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"


def normalize_code(value: str) -> str:
    code = re.sub(r"[\s-]", "", value.upper())
    if len(code) != 32 or any(char not in ALPHABET for char in code):
        raise ValueError("복구 코드 32자리를 확인해주세요.")
    return code


class Model(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)


class ProductSpec(Model):
    identity: str = Field(default="", max_length=50)
    volume: float | None = Field(default=None, gt=0, le=1_000_000)
    unit: str = Field(default="", max_length=12)
    packCount: int = Field(default=1, ge=1, le=999, strict=True)
    conditionKnown: bool = False
    allocated: bool = True

    def comparable(self) -> bool:
        return bool(
            self.identity.strip()
            and self.volume
            and self.unit.strip()
            and self.conditionKnown
            and self.allocated
        )


class Purchase(Model):
    receiptId: str = Field(max_length=100)
    itemId: str = Field(max_length=200)
    productKey: str = Field(default="other", max_length=500)
    store: str = Field(min_length=1, max_length=50)
    purchasedOn: str
    quantity: int = Field(ge=1, le=999, strict=True)
    total: int = Field(ge=0, le=9_999_999, strict=True)
    condition: str = Field(default="", max_length=120)
    share: bool = False
    spec: ProductSpec | None = None
    registeredAt: str | None = Field(default=None, max_length=40)

    @field_validator("purchasedOn")
    @classmethod
    def valid_date(cls, value: str) -> str:
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
            raise ValueError("날짜 형식을 확인해주세요.")
        date.fromisoformat(value)
        return value

    @field_validator("registeredAt")
    @classmethod
    def valid_timestamp(cls, value: str | None) -> str | None:
        if value:
            datetime.fromisoformat(value)
        return value


ROW_EXAMPLE = {
    "id": "shopping-1",
    "title": "우유",
    "completed": False,
    "quantity": 1,
    "deleted": False,
    "revision": "1791154800000000:device1",
    "pending": True,
    "baseRevision": None,
    "group": "1791154800000000:device1",
}


class Row(Model):
    id: str = Field(min_length=1, max_length=200)
    title: str = Field(min_length=1, max_length=50)
    completed: bool = False
    quantity: int | None = Field(default=None, ge=1, le=999, strict=True)
    note: str = Field(default="", max_length=120)
    purchase: Purchase | None = None
    deleted: bool = False
    revision: Revision
    pending: bool = False
    baseRevision: Revision | None = None
    group: str = Field(default="", max_length=120)

    @field_validator("title")
    @classmethod
    def valid_title(cls, value: str) -> str:
        if not value.strip() or "\n" in value or "\r" in value:
            raise ValueError("상품 이름을 확인해주세요.")
        return value


class SyncRequest(Model):
    rows: list[Row] = Field(max_length=1000)
    model_config = ConfigDict(
        extra="forbid", json_schema_extra={"example": {"rows": [ROW_EXAMPLE]}}
    )

    @field_validator("rows")
    @classmethod
    def unique_ids(cls, rows: list[Row]) -> list[Row]:
        if len({row.id for row in rows}) != len(rows):
            raise ValueError("중복된 기록 ID입니다.")
        return rows


class ConflictEntry(Model):
    local: Row
    remote: Row | None


class Conflict(Model):
    group: str
    entries: list[ConflictEntry]


class SyncResult(Model):
    rows: list[Row]
    conflicts: list[Conflict]
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "rows": [
                    {**ROW_EXAMPLE, "pending": False, "baseRevision": ROW_EXAMPLE["revision"]}
                ],
                "conflicts": [],
            }
        }
    )


class LoginRequest(Model):
    recoveryCode: str = Field(max_length=128)
    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={
            "example": {
                "recoveryCode": "2345-6789-ABCD-EFGH-JKLM-NPQR-STUV-WXYZ",
            }
        },
    )
    _normalize = field_validator("recoveryCode")(normalize_code)


class Session(Model):
    accountId: str
    token: str
    expiresAt: str
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "accountId": "da93dbf9-361c-4bc9-a5f1-c527f5897f54",
                "token": "example-session-token-use-the-issued-token",
                "expiresAt": "2027-10-05T00:00:00+00:00",
            }
        }
    )


class CreatedAccount(Session):
    recoveryCode: str
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                **Session.model_config["json_schema_extra"]["example"],
                "recoveryCode": "2345-6789-ABCD-EFGH-JKLM-NPQR-STUV-WXYZ",
            }
        }
    )


class PublishRequest(Model):
    rowIds: list[Annotated[str, Field(min_length=1, max_length=200)]] = Field(max_length=1000)
    model_config = ConfigDict(
        extra="forbid", json_schema_extra={"example": {"rowIds": ["purchase-1"]}}
    )


class Price(Model):
    id: str
    title: str
    purchase: Purchase


class Prices(Model):
    records: list[Price]
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "records": [
                    {
                        "id": "278fa5d37cd4",
                        "title": "서울우유",
                        "purchase": {
                            "receiptId": "",
                            "itemId": "",
                            "productKey": "v2-c11c",
                            "store": "마트",
                            "purchasedOn": "2026-10-05",
                            "quantity": 1,
                            "total": 2500,
                            "share": True,
                            "condition": "",
                            "registeredAt": "2026-10-05T10:00:00",
                            "spec": {
                                "identity": "서울우유",
                                "volume": 1000,
                                "unit": "ml",
                                "packCount": 1,
                                "conditionKnown": True,
                                "allocated": True,
                            },
                        },
                    }
                ]
            }
        }
    )


class Message(Model):
    detail: str
    model_config = ConfigDict(json_schema_extra={"example": {"detail": "처리했습니다."}})
