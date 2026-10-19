import unittest
from models import Purchase, Row, ROW_EXAMPLE, SyncRequest, SyncResult
from main import app, refresh_prices


# [OCR 추가] DB 없이 계약·직렬화·공유 필터를 실제 서버 모델로 확인한다.
class ReceiptSetTest(unittest.TestCase):
    def purchase(self, **changes):
        data = dict(receiptId='receipt-set', itemId='', store='마트',
                    purchasedOn='2026-10-01', quantity=2, total=0)
        data.update(changes)
        return Purchase(**data)

    def test_sync_response_preserves_set_relation(self):
        purchase = self.purchase(setParentId='purchase-receipt-set-parent')
        row = Row(**{**ROW_EXAMPLE, 'purchase': purchase})
        request = SyncRequest.model_validate_json(SyncRequest(rows=[row]).model_dump_json())
        response = SyncResult(rows=request.rows, conflicts=[])
        decoded = SyncResult.model_validate_json(response.model_dump_json())
        self.assertEqual(decoded.rows[0].purchase.setParentId, purchase.setParentId)
        self.assertEqual(decoded.rows[0].purchase.quantity, 2)
        self.assertEqual(decoded.rows[0].purchase.total, 0)
        self.assertEqual(self.purchase().setParentId, '')
        self.assertIn('setParentId', app.openapi()['components']['schemas']['Purchase']['properties'])

    def test_set_component_is_not_published_as_standalone_price(self):
        class Connection:
            def __init__(self):
                self.calls = []
            def execute(self, query, parameters):
                self.calls.append(query)
        connection = Connection()
        purchase = self.purchase(setParentId='purchase-receipt-set-parent',
                                 share=True, registeredAt='2026-10-01T10:00:00',
                                 spec=dict(identity='세제', volume=1, unit='L',
                                           conditionKnown=True, allocated=True))
        refresh_prices(connection, 'account-test', [Row(**{**ROW_EXAMPLE, 'purchase': purchase})])
        self.assertEqual(len(connection.calls), 1)
        self.assertTrue(connection.calls[0].startswith('DELETE'))


if __name__ == '__main__':
    unittest.main()
