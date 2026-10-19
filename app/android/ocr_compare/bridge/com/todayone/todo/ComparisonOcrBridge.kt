package com.todayone.todo

import android.content.Context
import android.graphics.BitmapFactory
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import org.json.JSONArray
import java.util.concurrent.Executors

/** [OCR 추가] 비교용 네이티브 인식기를 세션별로 소유하며 다른 엔진 결과로 보완하지 않는다. */
class ComparisonOcrBridge(context: Context, messenger: BinaryMessenger) : AutoCloseable {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, "howmuch/ocr_comparison")
    private val executor = Executors.newSingleThreadExecutor()
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private val sessions = mutableMapOf<String, AutoCloseable>()
    private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (closed) {
                result.error("closed", "인식기가 종료됐습니다.", null)
            } else if (call.method !in listOf("recognize", "close", "prepareCases", "clearCases")) {
                result.notImplemented()
            } else {
                // [OCR 추가] 추론과 모델 로딩으로 화면 스레드를 막지 않는다.
                executor.execute {
                    try {
                        val id = call.argument<String>("id") ?: "comparison-fixtures"
                        val response = if (call.method == "prepareCases") {
                            prepareCases(call.argument<String>("suite") ?: "base")
                        } else if (call.method == "clearCases") {
                            File(appContext.cacheDir, "ocr-comparison-inputs").deleteRecursively()
                            null
                        } else if (call.method == "close") {
                            sessions.remove(id)?.close()
                            null
                        } else {
                            val engine = call.argument<String>("engine") ?: error("엔진이 없습니다.")
                            val path = call.argument<String>("path") ?: error("사진이 없습니다.")
                            when (engine) {
                                "paddle" -> {
                                    val reader = sessions.getOrPut(id) { PaddleReader(appContext) }
                                    check(reader is PaddleReader) { "세션 엔진이 변경됐습니다." }
                                    reader.read(path)
                                }
                                "tesseract" -> {
                                    val reader = sessions.getOrPut(id) { TesseractReader(appContext) }
                                    check(reader is TesseractReader) { "세션 엔진이 변경됐습니다." }
                                    reader.read(path, call.argument<Int>("psm") ?: 3)
                                }
                                else -> error("지원하지 않는 비교 엔진입니다: $engine")
                            }
                        }
                        handler.post { result.success(response) }
                    } catch (error: Exception) {
                        // [OCR 추가] 실패를 빈 성공 응답으로 바꾸거나 ML Kit로 대체하지 않는다.
                        handler.post { result.error("ocr_failed", error.message, null) }
                    }
                }
            }
        }
    }

    /** [OCR 추가] 동일 파일 시험을 위해서만 고정 사진을 임시 경로에 복사한다. */
    private fun prepareCases(suite: String): List<Map<String, Any?>> {
        require(suite == "base" || suite == "padding")
        val assetFolder = if (suite == "padding") "padding" else "comparison"
        val manifest = appContext.assets.open("$assetFolder/manifest.json")
            .bufferedReader().use { JSONArray(it.readText()) }
        val folder = File(appContext.cacheDir, "ocr-comparison-inputs/$suite")
        check(folder.exists() || folder.mkdirs())
        return (0 until manifest.length()).map { index ->
            val item = manifest.getJSONObject(index)
            val id = item.getString("id")
            val photo = File(folder, "$id.png")
            appContext.assets.open("$assetFolder/$id.png").use { input ->
                photo.outputStream().use { output -> input.copyTo(output) }
            }
            mapOf("id" to id, "sha256" to item.getString("sha256"),
                "kind" to item.getString("kind"), "path" to photo.absolutePath)
        }
    }

    override fun close() {
        if (closed) return
        closed = true
        channel.setMethodCallHandler(null)
        // [OCR 추가] 이미 진행 중인 추론이 끝난 후에 모델을 해제한다.
        executor.execute {
            sessions.values.forEach { it.close() }
            sessions.clear()
        }
        executor.shutdown()
    }
}

/** [OCR 추가] 한 세션의 Tesseract만 사용하며 kor+eng 언어 데이터는 기존 시험과 동일하다. */
private class TesseractReader(context: Context) : AutoCloseable {
    private val reader = TessBaseAPI()

    init {
        val directory = File(context.filesDir, "ocr_comparison/tessdata")
        check(directory.exists() || directory.mkdirs()) { "언어 데이터 폴더 준비 실패" }
        for (language in listOf("kor", "eng")) {
            val target = File(directory, "$language.traineddata")
            if (!target.exists()) {
                context.assets.open("tessdata/$language.traineddata").use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                }
            }
        }
        if (!reader.init(directory.parent, "kor+eng", TessBaseAPI.OEM_LSTM_ONLY)) {
            reader.recycle()
            error("한국어 Tesseract 초기화 실패")
        }
    }

    fun read(path: String, psm: Int): Map<String, Any?> {
        require(psm in listOf(3, 7, 10)) { "지원하지 않는 PSM입니다." }
        // [OCR 추가] 이전 한 글자 시험 설정이 다음 사진에 전파되지 않도록 매번 설정한다.
        reader.setPageSegMode(psm)
        reader.setVariable("tessedit_char_whitelist", if (psm == 10) "0123456789" else "")
        val image = BitmapFactory.decodeFile(path) ?: error("사진을 읽을 수 없습니다.")
        try {
            reader.setImage(image)
            val text = reader.getUTF8Text()?.trim() ?: ""
            val lines = mutableListOf<MutableMap<String, Any?>>()
            val iterator = reader.getResultIterator()
            if (iterator != null) {
                try {
                    iterator.begin()
                    do {
                        val word = iterator.getUTF8Text(3)?.trim().orEmpty()
                        if (word.isEmpty()) continue
                        if (lines.isEmpty() || iterator.isAtBeginningOf(2)) {
                            val line = receiptOcrToken(iterator.getUTF8Text(2)?.trim().orEmpty(),
                                receiptRectPoints(iterator.getBoundingBox(2)),
                                iterator.confidence(2).toDouble() / 100).toMutableMap()
                            line["elements"] = mutableListOf<Map<String, Any?>>()
                            lines.add(line)
                        }
                        @Suppress("UNCHECKED_CAST")
                        val elements = lines.last()["elements"] as MutableList<Map<String, Any?>>
                        elements.add(receiptOcrToken(word, receiptRectPoints(iterator.getBoundingBox(3)),
                            iterator.confidence(3).toDouble() / 100))
                    } while (iterator.next(3))
                } finally {
                    iterator.delete()
                }
            }
            return mapOf("text" to text, "lines" to lines, "engine" to "tesseract",
                "version" to reader.getVersion(), "psm" to psm)
        } finally {
            reader.clear()
            image.recycle()
        }
    }

    override fun close() { reader.recycle() }
}
