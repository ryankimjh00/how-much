import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // UIScene이 화면의 엔진을 만든 뒤 저장소·카메라 플러그인을 등록한다.
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
