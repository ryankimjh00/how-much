package com.todayone.todo

import android.content.Context
import android.graphics.PointF
import com.paddle.ocr.EngineConfig
import com.paddle.ocr.PaddleOCR
import com.paddle.ocr.PaddleOCRConfig
import com.paddle.ocr.util.OpenCVUtils
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.runBlocking
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.atan2

/** [OCR 추가] 전체·부분 Paddle 인식을 세션별로 재사용하고 종료 후 해제한다. */
class ReceiptOcrBridge(context: Context, messenger: BinaryMessenger) : AutoCloseable {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, "howmuch/receipt_ocr")
    private val executor = Executors.newSingleThreadExecutor()
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private val sessions = mutableMapOf<String, PaddleReader>()
    private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (closed) {
                result.error("closed", "인식기가 종료됐습니다.", null)
                return@setMethodCallHandler
            }
            if (call.method != "recognize" && call.method != "close") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            // [OCR 추가] 모델 초기화·추론을 화면 스레드에서 실행하지 않는다.
            // 인식과 해제를 같은 큐에서 처리하여 실행 중 모델을 해제하지 않는다.
            executor.execute {
                try {
                    val id = call.argument<String>("id") ?: error("세션이 없습니다.")
                    val response = if (call.method == "close") {
                        sessions.remove(id)?.close()
                        null
                    } else {
                        require(call.argument<String>("engine") == "paddle") { "Paddle 엔진을 지정해주세요." }
                        val path = call.argument<String>("path") ?: error("사진이 없습니다.")
                        sessions.getOrPut(id) { PaddleReader(appContext) }.read(path)
                    }
                    handler.post { result.success(response) }
                } catch (error: Exception) {
                    // [OCR 추가] 실패는 화면의 기존 오류 처리로 전달하며 ML Kit로 보완하지 않는다.
                    handler.post { result.error("ocr_failed", error.message, null) }
                }
            }
        }
    }

    override fun close() {
        if (closed) return
        closed = true
        channel.setMethodCallHandler(null)
        executor.execute {
            sessions.values.forEach { it.close() }
            sessions.clear()
        }
        executor.shutdown()
    }
}

/** [OCR 추가] 글줄과 단어의 원래 상자를 공통 Flutter 데이터로 전달한다. */
internal fun receiptOcrToken(text: String, points: List<PointF>, confidence: Double?): Map<String, Any?> {
    val left = points.minOf { it.x }.toDouble()
    val top = points.minOf { it.y }.toDouble()
    val right = points.maxOf { it.x }.toDouble()
    val bottom = points.maxOf { it.y }.toDouble()
    val angle = Math.toDegrees(atan2(
        (points[1].y - points[0].y).toDouble(),
        (points[1].x - points[0].x).toDouble(),
    ))
    return mapOf(
        "text" to text, "bounds" to listOf(left, top, right, bottom),
        "points" to points.map { listOf(it.x.toDouble(), it.y.toDouble()) },
        "confidence" to confidence, "angle" to angle,
    )
}

internal fun receiptRectPoints(bounds: IntArray): List<PointF> = listOf(
    PointF(bounds[0].toFloat(), bounds[1].toFloat()),
    PointF(bounds[2].toFloat(), bounds[1].toFloat()),
    PointF(bounds[2].toFloat(), bounds[3].toFloat()),
    PointF(bounds[0].toFloat(), bounds[3].toFloat()),
)

/** [OCR 추가] Ubuntu에서 시험했던 한국어 가중치를 ONNX로 변환해 Android에서 실행한다. */
internal class PaddleReader(context: Context) : AutoCloseable {
    private val reader: PaddleOCR = runBlocking {
        check(OpenCVUtils.init(context)) { "OpenCV 초기화에 실패했습니다." }
        // [OCR 수정] 4000px 기본 검출은 12MP 원본에서 약 1.9GB를 써 종료됐다.
        // 원본 입력·결과 좌표는 유지하고 검출기 내부 해상도만 1600px로 제한한다.
        PaddleOCR.create(context, PaddleOCRConfig(detMaxSideLimit = 1600), EngineConfig(numThreads = 4))
    }

    fun read(path: String): Map<String, Any?> = runBlocking {
        val output = reader.recognize(File(path).readBytes())
        val lines = output.results.map { item ->
            val value = receiptOcrToken(item.text, item.box.points, item.confidence.toDouble())
            value + ("elements" to listOf(value))
        }
        mapOf("text" to output.results.joinToString("\n") { it.text }, "lines" to lines,
            "engine" to "paddle", "coldLoadMs" to output.coldLoadTimeMs)
    }

    override fun close() = runBlocking { reader.release() }
}

