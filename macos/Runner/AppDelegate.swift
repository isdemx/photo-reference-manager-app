import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let openFilesChannelName = "refma/macos_open_files"
  private var openFilesChannel: FlutterMethodChannel?
  private var pendingOpenFiles: [String] = []
  private var activeSecurityScopedURLs: [URL] = []

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
      case "requestFolderAccess":
        guard let folderPath = call.arguments as? String else {
          result(nil)
          return
        }
        self.requestFolderAccess(folderPath: folderPath, result: result)
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

  private func requestFolderAccess(folderPath: String, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let folderURL = URL(fileURLWithPath: folderPath, isDirectory: true)
      let panel = NSOpenPanel()
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.allowsMultipleSelection = false
      panel.canCreateDirectories = false
      panel.directoryURL = folderURL
      panel.prompt = "Allow"
      panel.message = "Allow Refma to read this folder so Lite Viewer can show nearby photos."

      let response = panel.runModal()
      guard response == .OK, let selectedURL = panel.url else {
        print("[RefmaOpenFiles][native] requestFolderAccess cancelled folder=\(folderPath)")
        result(nil)
        return
      }

      if selectedURL.startAccessingSecurityScopedResource() {
        self.activeSecurityScopedURLs.append(selectedURL)
      }

      print("[RefmaOpenFiles][native] requestFolderAccess granted folder=\(selectedURL.path)")
      result(selectedURL.path)
    }
  }

}
