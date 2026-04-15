import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let openFilesChannelName = "refma/macos_open_files"
  private var openFilesChannel: FlutterMethodChannel?
  private var pendingOpenFiles: [String] = []

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    let normalized = NSString(string: filename).expandingTildeInPath
    print("[RefmaOpenFiles][native] application(openFile:) filename=\(normalized)")
    enqueueOpenPaths([normalized])
    return true
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    let normalized = filenames.map { NSString(string: $0).expandingTildeInPath }
    print("[RefmaOpenFiles][native] application(openFiles:) filenames=\(normalized)")
    enqueueOpenPaths(normalized)
    sender.reply(toOpenOrPrint: .success)
  }

  @available(macOS 10.13, *)
  override func application(_ application: NSApplication, open urls: [URL]) {
    let paths = urls.map { $0.path }
    print("[RefmaOpenFiles][native] application(open urls:) urls=\(paths)")
    enqueueOpenPaths(paths)
  }

  func configureOpenFilesChannel(with controller: FlutterViewController) {
    guard openFilesChannel == nil else {
      return
    }
    print("[RefmaOpenFiles][native] configureOpenFilesChannel")

    let channel = FlutterMethodChannel(
      name: openFilesChannelName,
      binaryMessenger: controller.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: nil, details: nil))
        return
      }

      switch call.method {
      case "getPendingOpenFiles":
        print("[RefmaOpenFiles][native] getPendingOpenFiles -> \(self.pendingOpenFiles)")
        result(self.pendingOpenFiles)
        self.pendingOpenFiles.removeAll()
      default:
        print("[RefmaOpenFiles][native] methodNotImplemented \(call.method)")
        result(FlutterMethodNotImplemented)
      }
    }

    openFilesChannel = channel
    flushPendingOpenFiles()
  }

  private func flushPendingOpenFiles() {
    guard !pendingOpenFiles.isEmpty else {
      return
    }
    guard let channel = openFilesChannel else {
      print("[RefmaOpenFiles][native] flushPendingOpenFiles skipped: channel=nil pending=\(pendingOpenFiles)")
      return
    }

    let payload = pendingOpenFiles
    print("[RefmaOpenFiles][native] invoke openFiles payload=\(payload)")
    channel.invokeMethod("openFiles", arguments: payload)
    pendingOpenFiles.removeAll()
  }

  private func enqueueOpenPaths(_ paths: [String]) {
    let normalized = paths
      .map { NSString(string: $0).expandingTildeInPath }
      .filter { !$0.isEmpty }

    guard !normalized.isEmpty else {
      print("[RefmaOpenFiles][native] enqueueOpenPaths skipped: empty")
      return
    }

    pendingOpenFiles.append(contentsOf: normalized)
    flushPendingOpenFiles()
  }

}
