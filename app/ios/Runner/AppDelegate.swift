import Flutter
import UIKit
import Vision
import ImageIO

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // UIScene이 화면의 엔진을 만든 뒤 저장소·카메라 플러그인을 등록한다.
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MemoTextRecognizer") {
      MemoTextRecognizer.register(with: registrar)
    }
  }
}

/// 손글씨 메모만 Vision으로 처리하며 영수증의 ML Kit 연결은 유지한다.
class MemoTextRecognizer: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "how_much/memo_text_recognizer", binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(MemoTextRecognizer(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "recognize" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String, !path.isEmpty
    else {
      result(FlutterError(code: "invalid_image", message: "메모 사진 경로가 없습니다.", details: nil))
      return
    }
    // 큰 사진의 디코딩과 인식은 화면을 막지 않는다. 사진·인식문은 저장하거나 전송하지 않는다.
    DispatchQueue.global(qos: .userInitiated).async {
      let response: Any
      do {
        response = try autoreleasepool { try Self.recognize(path: path) }
      } catch {
        response = FlutterError(code: "vision_failed", message: "메모 사진을 읽지 못했어요.", details: nil)
      }
      DispatchQueue.main.async { result(response) }
    }
  }

  /// EXIF 방향을 반영하고 최대 3000px로 제한해 사진 크기에 따른 메모리 급증을 막는다.
  static func recognize(path: String) throws -> String {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 3000,
      ] as CFDictionary)
    else {
      throw NSError(domain: "MemoTextRecognizer", code: 1)
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    // 지원 여부를 확인해 구형 iOS에서 다른 언어로 조용히 대체하지 않는다.
    let supported = try request.supportedRecognitionLanguages()
    guard supported.contains("ko-KR") else {
      throw NSError(domain: "MemoTextRecognizer", code: 2)
    }
    request.recognitionLanguages = ["ko-KR", "en-US"].filter { supported.contains($0) }
    request.usesLanguageCorrection = true
    try VNImageRequestHandler(cgImage: image).perform([request])
    return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
      .joined(separator: "\n")
  }
}
