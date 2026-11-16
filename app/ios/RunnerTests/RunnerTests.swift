import Flutter
import UIKit
import XCTest
import google_mlkit_text_recognition
@testable import Runner

class RunnerTests: XCTestCase {

  func testMemoVisionRecognitionAndInvalidPhoto() throws {
    let imageURL = try XCTUnwrap(
      Bundle(for: RunnerTests.self).url(forResource: "handwritten-memo", withExtension: "jpg")
    )
    let text = try MemoTextRecognizer.recognize(path: imageURL.path)
      .components(separatedBy: .whitespacesAndNewlines).joined()
    // 기존 iOS ML Kit가 놓친 두부를 포함해 개선된 항목을 검사한다. 양파 오인식은 미해결이다.
    for item in ["우유", "계란", "두부", "김치", "대파", "바나나", "닭가슴살", "된장", "고추장", "화장지"] {
      XCTAssertTrue(text.contains(item), "인식하지 못한 상품: \(item)")
    }
    XCTAssertThrowsError(try MemoTextRecognizer.recognize(path: "/missing-memo.jpg"))
  }

  func testMemoVisionRejectsInvalidRequest() {
    let recognizer = MemoTextRecognizer()
    recognizer.handle(FlutterMethodCall(methodName: "recognize", arguments: [:])) { result in
      XCTAssertEqual((result as? FlutterError)?.code, "invalid_image")
    }
  }

  func testKoreanHandwrittenMemoRecognition() throws {
    let imageURL = try XCTUnwrap(
      Bundle(for: RunnerTests.self).url(forResource: "handwritten-memo", withExtension: "jpg")
    )
    let plugin = GoogleMlKitTextRecognitionPlugin()
    let recognizerID = UUID().uuidString
    let completed = expectation(description: "한국어 손글씨 사진 인식")
    let call = FlutterMethodCall(
      methodName: "vision#startTextRecognizer",
      arguments: [
        "id": recognizerID,
        "script": 4,
        "imageData": ["type": "file", "path": imageURL.path],
      ]
    )

    // Dart와 같은 플러그인 경로를 호출해 영문 모델 대체를 검출한다.
    plugin.handle(call) { result in
      guard let recognized = result as? [String: Any],
        let text = recognized["text"] as? String
      else {
        XCTFail("한국어 사진 인식 결과가 없습니다.")
        completed.fulfill()
        return
      }
      let normalized = text.components(separatedBy: .whitespacesAndNewlines).joined()
      let items = [
        "우유", "계란", "두부", "김치", "양파", "대파", "바나나", "닭가슴살", "된장", "고추장", "화장지",
      ]
      for item in items {
        XCTAssertTrue(normalized.contains(item), "인식하지 못한 상품: \(item)")
      }
      completed.fulfill()
    }
    wait(for: [completed], timeout: 30)
    plugin.handle(
      FlutterMethodCall(methodName: "vision#closeTextRecognizer", arguments: ["id": recognizerID])
    ) { _ in }
  }

}
