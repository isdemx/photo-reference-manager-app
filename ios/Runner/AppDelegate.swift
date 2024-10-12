
import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let tempDirChannel = FlutterMethodChannel(name: "my_app/temp_dir",
                                              binaryMessenger: controller.binaryMessenger)
    tempDirChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getNSTemporaryDirectory" {
        let tmpDir = NSTemporaryDirectory()
        result(tmpDir)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    // Устанавливаем черный фон для всего окнаr
    window?.backgroundColor = UIColor.black

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
