package com.todayone.todo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine // [OCR 추가]
import io.flutter.plugin.common.BinaryMessenger // [OCR 추가]
import android.content.Context // [OCR 추가]

class MainActivity : FlutterActivity() {
    private var receiptBridge: ReceiptOcrBridge? = null // [OCR 추가]
    private var comparisonBridge: AutoCloseable? = null // [OCR 추가]

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        receiptBridge = ReceiptOcrBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger) // [OCR 추가]
        // [OCR 수정] 비교 사진·Tesseract 채널은 비교 옵션이 있을 때만 추가한다.
        val bridgeClass = try {
            Class.forName("com.todayone.todo.ComparisonOcrBridge")
        } catch (_: ClassNotFoundException) {
            return
        }
        comparisonBridge = bridgeClass
            .getConstructor(Context::class.java, BinaryMessenger::class.java)
            .newInstance(applicationContext, flutterEngine.dartExecutor.binaryMessenger) as AutoCloseable
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        receiptBridge?.close() // [OCR 추가] 화면 종료 후 진행 중 작업부터 마무리한다.
        receiptBridge = null
        comparisonBridge?.close() // [OCR 추가] 진행 중인 추론 뒤에 모델을 정리한다.
        comparisonBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
