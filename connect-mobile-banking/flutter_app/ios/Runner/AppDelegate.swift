import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Notifications that arrive while the app is open (the simulated push) are shown as banners and their taps
    // reach Flutter's notification plugin.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // The native call (Amazon Chime SDK), for the assistant's calls.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ConnectCallPlugin") {
      ConnectCallPlugin.register(with: registrar)
    }
  }
}
