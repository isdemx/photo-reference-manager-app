import Cocoa

protocol OverlayWindowDelegate: AnyObject {
  func overlayWindowDidCancel(_ window: OverlayWindow)
  func overlayWindow(_ window: OverlayWindow, didConfirmWith rect: CGRect, action: String)
}

final class OverlayWindow: NSWindow {

  weak var overlayDelegate: OverlayWindowDelegate?
  let targetScreen: NSScreen?
  private let overlayView = OverlayContentView()

  init(screen: NSScreen) {
    self.targetScreen = screen
    let rect = screen.frame
    super.init(
      contentRect: rect,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )

    level = .screenSaver
    isOpaque = false
    backgroundColor = .clear
    ignoresMouseEvents = false
    hasShadow = false
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    setFrame(rect, display: true)

    contentView = overlayView

    overlayView.onCancel = { [weak self] in
      guard let self = self else { return }
      print("[OverlayWindow] onCancel on \(self.targetScreen?.localizedName ?? "unknown screen")")
      self.overlayDelegate?.overlayWindowDidCancel(self)
    }
    overlayView.onAction = { [weak self] rect, action in
      guard let self = self else { return }
      print("[OverlayWindow] onAction=\(action) rect=\(rect) on \(self.targetScreen?.localizedName ?? "unknown")")
      self.overlayDelegate?.overlayWindow(self, didConfirmWith: rect, action: action)
    }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func show() {
    print("[OverlayWindow] show() on \(targetScreen?.localizedName ?? "unknown")")
    makeKeyAndOrderFront(nil)
    orderFrontRegardless()
    NSApp.activate(ignoringOtherApps: true)
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

// MARK: - Content

final class OverlayContentView: NSView {

  var onCancel: (() -> Void)?
  var onAction: ((CGRect, String) -> Void)?

  private var dragging = false
  private var startPoint: CGPoint = .zero
  private var currentRect: CGRect? { didSet { needsDisplay = true; layoutButtons() } }

  private let dimColor = NSColor.black.withAlphaComponent(0.15)
  private let borderColor = NSColor.white
  private let borderWidth: CGFloat = 2.0

  private lazy var btnShot: NSButton = {
    let b = NSButton(title: "📸 Скриншот", target: self, action: #selector(doShot))
    b.bezelStyle = .rounded
    b.setButtonType(.momentaryPushIn)
    return b
  }()
  private lazy var btnRec: NSButton = {
    let b = NSButton(title: "⏺ Запись", target: self, action: #selector(doRec))
    b.bezelStyle = .rounded
    b.setButtonType(.momentaryPushIn)
    return b
  }()
  private lazy var btnClose: NSButton = {
    let b = NSButton(title: "✕", target: self, action: #selector(doClose))
    b.bezelStyle = .rounded
    b.setButtonType(.momentaryPushIn)
    return b
  }()

  private var buttonsAdded = false
  private var busy = false

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    dimColor.setFill()
    dirtyRect.fill()

    if let r = currentRect {
      NSColor.clear.setFill()
      r.fill()
      borderColor.setStroke()
      let p = NSBezierPath(rect: r)
      p.lineWidth = borderWidth
      p.stroke()
    }

    if !buttonsAdded {
      buttonsAdded = true
      addSubview(btnShot)
      addSubview(btnRec)
      addSubview(btnClose)
      layoutButtons()
      print("[OverlayContentView] buttons added")
    }
  }

  private func normRect(from p1: CGPoint, to p2: CGPoint) -> CGRect {
    CGRect(x: min(p1.x, p2.x),
           y: min(p1.y, p2.y),
           width: abs(p2.x - p1.x),
           height: abs(p2.y - p1.y))
  }

  override func mouseDown(with event: NSEvent) {
    dragging = true
    startPoint = convert(event.locationInWindow, from: nil)
    currentRect = CGRect(origin: startPoint, size: .zero)
    print("[OverlayContentView] mouseDown at \(startPoint)")
  }

  override func mouseDragged(with event: NSEvent) {
    guard dragging else { return }
    let cur = convert(event.locationInWindow, from: nil)
    currentRect = normRect(from: startPoint, to: cur)
  }

  override func mouseUp(with event: NSEvent) {
    dragging = false
  }

  private func layoutButtons() {
    guard let r = currentRect else {
      btnShot.isHidden = true
      btnRec.isHidden = true
      btnClose.isHidden = true
      return
    }
    btnShot.isHidden = false
    btnRec.isHidden = false
    btnClose.isHidden = false

    let padding: CGFloat = 8
    let buttonSize = CGSize(width: 120, height: 28)
    btnShot.frame  = CGRect(x: r.minX,       y: r.minY - buttonSize.height - padding, width: buttonSize.width, height: buttonSize.height)
    btnRec.frame   = CGRect(x: r.minX + 128, y: r.minY - buttonSize.height - padding, width: buttonSize.width, height: buttonSize.height)
    btnClose.frame = CGRect(x: r.maxX - 28,  y: r.maxY + padding,                     width: 28,               height: 28)
  }

  @objc private func doShot() {
    guard !busy, let r = currentRect else { return }
    busy = true
    print("[OverlayContentView] doShot rect=\(r)")
    onAction?(r, "shot")
  }
  @objc private func doRec() {
    guard !busy, let r = currentRect else { return }
    busy = true
    print("[OverlayContentView] doRec rect=\(r)")
    onAction?(r, "record")
  }
  @objc private func doClose() {
    guard !busy else { return }
    busy = true
    print("[OverlayContentView] doClose")
    onCancel?()
  }
}
