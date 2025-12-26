
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

    let sharedImportChannel = FlutterMethodChannel(
      name: "refma/shared_import",
      binaryMessenger: controller.binaryMessenger
    )
    sharedImportChannel.setMethodCallHandler { (call, result) in
      let appGroupId = "group.app.greenmonster.photoreferencemanager"
      let inboxFolder = "SharedInbox"
      let manifestKey = "refma.shared.import.manifest"
      let defaults = UserDefaults(suiteName: appGroupId)

      func containerURL() -> URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
      }

      switch call.method {
      case "getManifest":
        guard let defaults = defaults,
              let container = containerURL() else {
          result([])
          return
        }
        let manifest = defaults.array(forKey: manifestKey) as? [[String: Any]] ?? []
        let withPaths = manifest.compactMap { entry -> [String: Any]? in
          guard let rel = entry["relativePath"] as? String else { return nil }
          let fileURL = container.appendingPathComponent(rel)
          if !FileManager.default.fileExists(atPath: fileURL.path) { return nil }
          var out = entry
          out["filePath"] = fileURL.path
          return out
        }
        result(withPaths)
      case "clearManifest":
        defaults?.set([], forKey: manifestKey)
        defaults?.synchronize()
        result(true)
      case "deleteSharedFiles":
        guard let args = call.arguments as? [String] else {
          result(false)
          return
        }
        for path in args {
          try? FileManager.default.removeItem(atPath: path)
        }
        if let container = containerURL() {
          let inboxURL = container.appendingPathComponent(inboxFolder, isDirectory: true)
          if let items = try? FileManager.default.contentsOfDirectory(atPath: inboxURL.path),
             items.isEmpty {
            try? FileManager.default.removeItem(at: inboxURL)
          }
        }
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let sharedTagsChannel = FlutterMethodChannel(
      name: "refma/shared_tags",
      binaryMessenger: controller.binaryMessenger
    )
    sharedTagsChannel.setMethodCallHandler { (call, result) in
      let appGroupId = "group.app.greenmonster.photoreferencemanager"
      let tagsKey = "refma.shared.tags.json"
      let defaults = UserDefaults(suiteName: appGroupId)

      switch call.method {
      case "setTagsJson":
        guard let json = call.arguments as? String else {
          result(false)
          return
        }
        defaults?.set(json, forKey: tagsKey)
        defaults?.synchronize()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    // Устанавливаем черный фон для всего окнаr
    window?.backgroundColor = UIColor.black

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
