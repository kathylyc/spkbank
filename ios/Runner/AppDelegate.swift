import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // 设置全屏模式
    if #available(iOS 11.0, *) {
      if let window = self.window {
        window.ignoresSafeArea = true
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func applicationDidBecomeActive(_ application: UIApplication) {
    // 确保应用激活时保持全屏
    if #available(iOS 11.0, *) {
      if let window = self.window {
        window.ignoresSafeArea = true
      }
    }
  }
}

