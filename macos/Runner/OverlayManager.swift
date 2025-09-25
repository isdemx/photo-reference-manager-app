import Cocoa

@objc final class OverlayManager: NSObject {

  private var windows: [OverlayWindow] = []
  private var onComplete: (([String: Any]) -> Void)?

  func presentOverlay(completion: @escaping ([String: Any]) -> Void) {
    onComplete = completion

    // ДЛЯ ДИАГНОСТИКИ: показываем ТОЛЬКО на главном экране
    let screens = NSScreen.screens
    guard let main = screens.first else {
      print("[OverlayManager] no screens found")
      completion(["action": "cancel"])
      return
    }
    print("[OverlayManager] presenting on screen: \(main.localizedName) frame=\(main.frame) scale=\(main.backingScaleFactor)")

    let win = OverlayWindow(screen: main)
    win.overlayDelegate = self
    win.show()
    windows.append(win)

    NSApp.activate(ignoringOtherApps: true)
  }

  private func dismissAll(with payload: [String: Any]?) {
    print("[OverlayManager] dismissAll payload=\(String(describing: payload))")
    let toClose = windows
    windows.removeAll()
    toClose.forEach { $0.orderOut(nil) }

    DispatchQueue.main.async {
      toClose.forEach { $0.close() }

      let result = payload ?? ["action": "cancel"]
      let completion = self.onComplete
      self.onComplete = nil

      DispatchQueue.main.async {
        print("[OverlayManager] calling completion")
        completion?(result)
      }
    }
  }
}

extension OverlayManager: OverlayWindowDelegate {
  func overlayWindowDidCancel(_ window: OverlayWindow) {
    print("[OverlayManager] delegate cancel")
    dismissAll(with: nil)
  }

  func overlayWindow(_ window: OverlayWindow, didConfirmWith rect: CGRect, action: String) {
    print("[OverlayManager] delegate confirm action=\(action) rect=\(rect)")

    guard let screen = window.targetScreen else {
      dismissAll(with: ["action": "cancel"])
      return
    }

    let scale = screen.backingScaleFactor
    // переводим в пиксели + инвертируем Y (origin macOS внизу)
    let pxRect = CGRect(
      x: rect.origin.x * scale,
      y: (screen.frame.height - rect.maxY) * scale,
      width: rect.size.width * scale,
      height: rect.size.height * scale
    )

    let payload: [String: Any] = [
      "action": action,
      "x": pxRect.origin.x,
      "y": pxRect.origin.y,
      "w": pxRect.size.width,
      "h": pxRect.size.height,
      "displayId": screen.localizedName
    ]
    print("[OverlayManager] payload -> Dart: \(payload)")
    dismissAll(with: payload)
  }
}
