import Flutter
import UIKit
import XCTest
import google_mlkit_text_recognition

class RunnerTests: XCTestCase {

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
