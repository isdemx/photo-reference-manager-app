import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let overlayManager = OverlayManager()
  private var isOverlayPresented = false

  override func awakeFromNib() {
    let windowFrame = self.frame
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "macos_overlay_picker",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      print("[MainFlutterWindow] MethodChannel call: \(call.method)")

      switch call.method {
      case "show":
        if self.isOverlayPresented {
          print("[MainFlutterWindow] overlay already presented — rejecting")
          result(FlutterError(code: "overlay_busy", message: "Overlay already presented", details: nil))
          return
        }
        self.isOverlayPresented = true

        DispatchQueue.main.async {
          print("[MainFlutterWindow] presenting overlay…")
          self.overlayManager.presentOverlay { payload in
            print("[MainFlutterWindow] overlay completion payload: \(payload)")
            DispatchQueue.main.async {
              result(payload)   // строго один раз
              self.isOverlayPresented = false
              print("[MainFlutterWindow] result sent to Dart")
            }
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
