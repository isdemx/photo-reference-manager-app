import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let openFilesChannelName = "refma/macos_open_files"
  private let folderAccessBookmarksKey = "refma.folderAccessBookmarks.v1"
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

    if openFilesChannel == nil {
      openFilesChannel = channel
      flushPendingOpenFiles()
    }
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
      if let restoredPath = self.restoreStoredFolderAccess(for: folderPath) {
        print("[RefmaOpenFiles][native] requestFolderAccess restored folder=\(restoredPath)")
        result(restoredPath)
        return
      }

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
      self.storeFolderAccessBookmark(for: selectedURL)

      print("[RefmaOpenFiles][native] requestFolderAccess granted folder=\(selectedURL.path)")
      result(selectedURL.path)
    }
  }

  private func normalizedFolderPath(_ path: String) -> String {
    let expanded = NSString(string: path).expandingTildeInPath
    return URL(fileURLWithPath: expanded).standardizedFileURL.path
  }

  private func path(_ path: String, isInsideOrEqualTo grantedPath: String) -> Bool {
    let normalizedPath = normalizedFolderPath(path)
    let normalizedGrantedPath = normalizedFolderPath(grantedPath)
    return normalizedPath == normalizedGrantedPath ||
      normalizedPath.hasPrefix(normalizedGrantedPath + "/")
  }

  private func folderAccessBookmarks() -> [String: Data] {
    return UserDefaults.standard.object(forKey: folderAccessBookmarksKey) as? [String: Data] ?? [:]
  }

  private func saveFolderAccessBookmarks(_ bookmarks: [String: Data]) {
    UserDefaults.standard.set(bookmarks, forKey: folderAccessBookmarksKey)
  }

  private func restoreStoredFolderAccess(for folderPath: String) -> String? {
    var bookmarks = folderAccessBookmarks()
    let matchingKeys = bookmarks.keys
      .filter { path(folderPath, isInsideOrEqualTo: $0) }
      .sorted { $0.count > $1.count }

    for key in matchingKeys {
      guard let data = bookmarks[key] else {
        continue
      }

      do {
        var isStale = false
        let url = try URL(
          resolvingBookmarkData: data,
          options: [.withSecurityScope],
          relativeTo: nil,
          bookmarkDataIsStale: &isStale
        )

        if url.startAccessingSecurityScopedResource() {
          activeSecurityScopedURLs.append(url)
        }

        if isStale {
          let refreshedData = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
          )
          bookmarks.removeValue(forKey: key)
          bookmarks[normalizedFolderPath(url.path)] = refreshedData
          saveFolderAccessBookmarks(bookmarks)
        }

        return url.path
      } catch {
        print("[RefmaOpenFiles][native] failed to restore folder bookmark key=\(key) error=\(error)")
        bookmarks.removeValue(forKey: key)
        saveFolderAccessBookmarks(bookmarks)
      }
    }

    return nil
  }

  private func storeFolderAccessBookmark(for url: URL) {
    do {
      let data = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      var bookmarks = folderAccessBookmarks()
      bookmarks[normalizedFolderPath(url.path)] = data
      saveFolderAccessBookmarks(bookmarks)
      print("[RefmaOpenFiles][native] stored folder bookmark path=\(url.path)")
    } catch {
      print("[RefmaOpenFiles][native] failed to store folder bookmark path=\(url.path) error=\(error)")
    }
  }

}
