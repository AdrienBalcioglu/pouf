import AppKit
import QuartzCore

// MARK: - Model

struct NoteData: Codable {
    var id = UUID()
    var text = ""
    var x: Double
    var y: Double
    var w: Double = 240
    var h: Double = 220
    var color = 0
    var expires: Date?
}

enum Store {
    static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Pouf", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("notes.json")
    }
    static func load() -> [NoteData] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([NoteData].self, from: data)) ?? []
    }
    static func save(_ notes: [NoteData]) {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(notes) { try? data.write(to: url, options: .atomic) }
    }
}

let palette: [NSColor] = [
    NSColor(red: 1.00, green: 0.95, blue: 0.62, alpha: 1), // yellow
    NSColor(red: 1.00, green: 0.82, blue: 0.70, alpha: 1), // peach
    NSColor(red: 0.78, green: 0.94, blue: 0.82, alpha: 1), // mint
    NSColor(red: 0.80, green: 0.89, blue: 1.00, alpha: 1), // sky
    NSColor(red: 0.93, green: 0.83, blue: 1.00, alpha: 1), // lilac
]
let ink = NSColor(red: 0.17, green: 0.16, blue: 0.12, alpha: 1)

// MARK: - Views

final class NotePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Draws the paper itself, so a snapshot of the view contains it.
final class PaperView: NSView {
    var color = palette[0] { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 9, yRadius: 9).fill()
        NSColor.black.withAlphaComponent(0.06).setFill()
        NSRect(x: 0, y: bounds.height - 30, width: bounds.width, height: 0.5).fill()
    }
}

// MARK: - One note

final class NoteController: NSObject, NSWindowDelegate, NSTextViewDelegate {
    var note: NoteData
    let panel: NotePanel
    private let paper = PaperView()
    private let textView = NSTextView()
    private let timerButton = NSButton()
    private var ticker: Timer?
    private var overlay: NSWindow?
    private var vanishing = false
    private unowned let owner: AppDelegate

    init(note: NoteData, owner: AppDelegate) {
        self.note = note
        self.owner = owner
        panel = NotePanel(contentRect: NSRect(x: note.x, y: note.y, width: note.w, height: note.h),
                          styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 170, height: 130)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.appearance = NSAppearance(named: .aqua)
        applyLevel()
        buildContent()
        refreshTimer()
    }

    func applyLevel() { panel.level = owner.keepOnTop ? .floating : .normal }

    private func barButton(_ title: String, _ action: Selector, tip: String) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.font = .systemFont(ofSize: 14, weight: .medium)
        button.contentTintColor = ink
        button.toolTip = tip
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    private func buildContent() {
        paper.color = palette[note.color % palette.count]
        panel.contentView = paper

        let add = barButton("＋", #selector(addNote), tip: "New note")
        timerButton.target = self; timerButton.action = #selector(showTimerMenu(_:))
        timerButton.isBordered = false; timerButton.toolTip = "Set a timer: the note disintegrates when it ends"
        timerButton.setContentHuggingPriority(.required, for: .horizontal)
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let tint = barButton("●", #selector(cycleColor), tip: "Change colour")
        tint.contentTintColor = ink.withAlphaComponent(0.35)
        let close = barButton("✕", #selector(discard), tip: "Throw away")

        let bar = NSStackView(views: [add, timerButton, spacer, tint, close])
        bar.orientation = .horizontal; bar.spacing = 10
        bar.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        bar.translatesAutoresizingMaskIntoConstraints = false

        let scroll = NSScrollView()
        scroll.drawsBackground = false; scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        textView.frame = NSRect(x: 0, y: 0, width: note.w - 12, height: note.h - 40)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true; textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.drawsBackground = false; textView.isRichText = false; textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 15); textView.textColor = ink; textView.insertionPointColor = ink
        textView.textContainerInset = NSSize(width: 6, height: 4)
        textView.string = note.text
        textView.delegate = self
        scroll.documentView = textView

        paper.addSubview(bar); paper.addSubview(scroll)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: paper.topAnchor), bar.heightAnchor.constraint(equalToConstant: 30),
            bar.leadingAnchor.constraint(equalTo: paper.leadingAnchor), bar.trailingAnchor.constraint(equalTo: paper.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 2),
            scroll.leadingAnchor.constraint(equalTo: paper.leadingAnchor, constant: 4),
            scroll.trailingAnchor.constraint(equalTo: paper.trailingAnchor, constant: -4),
            scroll.bottomAnchor.constraint(equalTo: paper.bottomAnchor, constant: -8),
        ])
    }

    func show(focus: Bool) {
        panel.orderFront(nil)
        if focus { panel.makeKeyAndOrderFront(nil); panel.makeFirstResponder(textView) }
    }

    // MARK: Editing and geometry

    func textDidChange(_ notification: Notification) { note.text = textView.string; owner.save() }
    func windowDidMove(_ notification: Notification) { storeFrame() }
    func windowDidResize(_ notification: Notification) { storeFrame() }
    private func storeFrame() {
        let f = panel.frame
        note.x = Double(f.origin.x); note.y = Double(f.origin.y); note.w = Double(f.width); note.h = Double(f.height)
        owner.save()
    }

    @objc private func addNote() { owner.newNote(near: panel.frame) }
    @objc private func cycleColor() {
        note.color = (note.color + 1) % palette.count
        paper.color = palette[note.color]; owner.save()
    }
    @objc func discard() { vanish(fast: true) }

    // MARK: Timer

    @objc private func showTimerMenu(_ sender: NSButton) {
        let menu = NSMenu()
        for (label, seconds) in [("10 seconds", 10.0), ("1 minute", 60), ("5 minutes", 300), ("15 minutes", 900), ("30 minutes", 1800), ("1 hour", 3600)] {
            let item = NSMenuItem(title: label, action: #selector(pickTimer(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = seconds; menu.addItem(item)
        }
        let custom = NSMenuItem(title: "Custom…", action: #selector(customTimer), keyEquivalent: ""); custom.target = self; menu.addItem(custom)
        if note.expires != nil {
            menu.addItem(.separator())
            let cancel = NSMenuItem(title: "Remove the timer", action: #selector(cancelTimer), keyEquivalent: ""); cancel.target = self; menu.addItem(cancel)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: -4), in: sender)
    }
    @objc private func pickTimer(_ item: NSMenuItem) { if let s = item.representedObject as? Double { setTimer(seconds: s) } }
    @objc private func cancelTimer() { note.expires = nil; owner.save(); refreshTimer() }
    @objc private func customTimer() {
        let alert = NSAlert()
        alert.messageText = "Disintegrate this note in…"
        alert.informativeText = "Minutes"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24)); field.stringValue = "10"
        alert.accessoryView = field
        alert.addButton(withTitle: "Start"); alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let minutes = Double(field.stringValue.replacingOccurrences(of: ",", with: ".")) ?? 0
        if minutes > 0 { setTimer(seconds: min(minutes, 60 * 24 * 30) * 60) }
    }
    func setTimer(seconds: Double) { note.expires = Date().addingTimeInterval(seconds); owner.save(); refreshTimer() }

    private func refreshTimer() {
        guard let expires = note.expires else {
            ticker?.invalidate(); ticker = nil
            setTimerTitle("⏱", color: ink.withAlphaComponent(0.55)); return
        }
        let left = expires.timeIntervalSinceNow
        if left <= 0 { vanish(fast: false); return }
        let s = Int(left.rounded(.up))
        let text = s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) : String(format: "%02d:%02d", s / 60, s % 60)
        setTimerTitle("⏱ " + text, color: left <= 10 ? NSColor(red: 0.75, green: 0.15, blue: 0.1, alpha: 1) : ink)
        if ticker == nil {
            let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.refreshTimer() }
            RunLoop.main.add(timer, forMode: .common); ticker = timer
        }
    }
    private func setTimerTitle(_ title: String, color: NSColor) {
        timerButton.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold), .foregroundColor: color,
        ])
    }

    // MARK: Disintegration

    /// Cuts a snapshot of the note into small tiles and blows them away like dust, starting from the right edge.
    func vanish(fast: Bool) {
        guard !vanishing else { return }
        vanishing = true
        ticker?.invalidate(); ticker = nil
        panel.makeFirstResponder(nil)
        let bounds = paper.bounds
        guard panel.isVisible, bounds.width > 1, let rep = paper.bitmapImageRepForCachingDisplay(in: bounds) else { finish(); return }
        paper.cacheDisplay(in: bounds, to: rep)
        guard let image = rep.cgImage else { finish(); return }

        let margin: CGFloat = 240
        let window = NSWindow(contentRect: panel.frame.insetBy(dx: -margin, dy: -margin), styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = false
        window.ignoresMouseEvents = true; window.level = panel.level; window.isReleasedWhenClosed = false
        window.collectionBehavior = panel.collectionBehavior
        let host = NSView(frame: NSRect(origin: .zero, size: window.frame.size))
        host.wantsLayer = true
        window.contentView = host
        guard let root = host.layer else { finish(); return }

        let scale = CGFloat(image.width) / bounds.width
        let tile: CGFloat = 6
        #if SLOWMO
        let speed = 8.0 // debug build only: slow enough to inspect the effect
        #else
        let speed = fast ? 0.55 : 1.0
        #endif
        let sweep = 1.1 * speed
        let now = root.convertTime(CACurrentMediaTime(), from: nil)
        var longest = 0.0

        CATransaction.begin(); CATransaction.setDisableActions(true)
        var y: CGFloat = 0
        while y < bounds.height {
            var x: CGFloat = 0
            let th = min(tile, bounds.height - y)
            while x < bounds.width {
                let tw = min(tile, bounds.width - x)
                // The bitmap's origin is top-left; the layer tree's is bottom-left.
                let crop = CGRect(x: x * scale, y: (bounds.height - y - th) * scale, width: tw * scale, height: th * scale)
                if let piece = image.cropping(to: crop) {
                    let layer = CALayer()
                    layer.contents = piece
                    layer.frame = CGRect(x: margin + x, y: margin + y, width: tw, height: th)
                    root.addSublayer(layer)

                    let delay = Double(1 - x / bounds.width) * sweep + Double.random(in: 0...0.28) * speed
                    let duration = Double.random(in: 0.7...1.25) * speed
                    let start = layer.position
                    let end = CGPoint(x: start.x + CGFloat.random(in: 50...190), y: start.y + CGFloat.random(in: -25...120))

                    let move = CABasicAnimation(keyPath: "position")
                    move.fromValue = NSValue(point: start); move.toValue = NSValue(point: end)
                    let fade = CABasicAnimation(keyPath: "opacity"); fade.fromValue = 1; fade.toValue = 0
                    let shrink = CABasicAnimation(keyPath: "transform.scale"); shrink.fromValue = 1; shrink.toValue = 0.15
                    let spin = CABasicAnimation(keyPath: "transform.rotation.z"); spin.fromValue = 0; spin.toValue = Double.random(in: -2.5...2.5)
                    let group = CAAnimationGroup()
                    group.animations = [move, fade, shrink, spin]
                    group.duration = duration; group.beginTime = now + delay
                    group.fillMode = .both; group.isRemovedOnCompletion = false
                    group.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    layer.add(group, forKey: "dust")
                    longest = max(longest, delay + duration)
                }
                x += tile
            }
            y += tile
        }
        CATransaction.commit()

        overlay = window
        window.orderFront(nil)
        panel.orderOut(nil)
        if !fast { NSSound(named: "Blow")?.play() }
        DispatchQueue.main.asyncAfter(deadline: .now() + longest + 0.15) { [weak self] in
            window.close(); self?.overlay = nil; self?.finish()
        }
    }

    private func finish() { panel.close(); owner.remove(self) }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controllers: [NoteController] = []
    private var statusItem: NSStatusItem?
    private var topItems: [NSMenuItem] = []
    var keepOnTop: Bool {
        get { UserDefaults.standard.object(forKey: "keepOnTop") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "keepOnTop") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenus()
        let saved = Store.load()
        // Notes whose timer ran out while the app was closed are simply gone.
        let alive = saved.filter { $0.expires == nil || $0.expires! > Date() }
        for note in alive { open(note, focus: false) }
        if saved.isEmpty {
            var welcome = NoteData(x: 0, y: 0)
            welcome.text = "Welcome to Pouf.\n\n＋ adds a note.\n⏱ starts a timer: when it ends, the note turns to dust.\n● changes the colour.\n✕ throws the note away."
            place(&welcome, near: nil); open(welcome, focus: true)
        }
        save()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if controllers.isEmpty { newNote(near: nil) } else { showAll() }
        return true
    }
    func applicationWillTerminate(_ notification: Notification) { save() }

    func save() { Store.save(controllers.map { $0.note }) }
    func remove(_ controller: NoteController) { controllers.removeAll { $0 === controller }; save() }

    private func open(_ note: NoteData, focus: Bool) {
        let controller = NoteController(note: note, owner: self)
        controllers.append(controller)
        controller.show(focus: focus)
    }
    private func place(_ note: inout NoteData, near frame: NSRect?) {
        let screen = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        var origin: NSPoint
        if let frame = frame { origin = NSPoint(x: frame.minX + 28, y: frame.minY - 28) }
        else { origin = NSPoint(x: screen.midX - CGFloat(note.w) / 2, y: screen.midY - CGFloat(note.h) / 2) }
        origin.x = min(max(origin.x, screen.minX + 8), screen.maxX - CGFloat(note.w) - 8)
        origin.y = min(max(origin.y, screen.minY + 8), screen.maxY - CGFloat(note.h) - 8)
        note.x = Double(origin.x); note.y = Double(origin.y)
    }
    func newNote(near frame: NSRect?) {
        var note = NoteData(x: 0, y: 0)
        note.color = controllers.count % palette.count
        place(&note, near: frame ?? controllers.last?.panel.frame)
        open(note, focus: true); save()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func newNoteAction() { newNote(near: nil) }
    @objc private func showAll() { NSApp.activate(ignoringOtherApps: true); controllers.forEach { $0.panel.orderFront(nil) } }
    @objc private func closeKeyNote() { controllers.first { $0.panel.isKeyWindow }?.discard() }
    @objc private func toggleOnTop() {
        keepOnTop.toggle()
        topItems.forEach { $0.state = keepOnTop ? .on : .off }
        controllers.forEach { $0.applyLevel() }
    }

    private func item(_ title: String, _ action: Selector?, _ key: String = "", target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = target; return item
    }
    private func onTopItem() -> NSMenuItem {
        let item = self.item("Keep Notes on Top", #selector(toggleOnTop), target: self)
        item.state = keepOnTop ? .on : .off; topItems.append(item); return item
    }
    private func buildMenus() {
        let main = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(item("About Pouf", #selector(NSApplication.orderFrontStandardAboutPanel(_:))))
        appMenu.addItem(.separator())
        appMenu.addItem(item("Hide Pouf", #selector(NSApplication.hide(_:)), "h"))
        appMenu.addItem(item("Quit Pouf", #selector(NSApplication.terminate(_:)), "q"))
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(item("New Note", #selector(newNoteAction), "n", target: self))
        fileMenu.addItem(item("Throw Away Note", #selector(closeKeyNote), "w", target: self))
        fileMenu.addItem(.separator())
        fileMenu.addItem(item("Show All Notes", #selector(showAll), target: self))
        fileMenu.addItem(onTopItem())
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(item("Undo", Selector(("undo:")), "z"))
        let redo = item("Redo", Selector(("redo:")), "z"); redo.keyEquivalentModifierMask = [.command, .shift]; editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(item("Cut", #selector(NSText.cut(_:)), "x"))
        editMenu.addItem(item("Copy", #selector(NSText.copy(_:)), "c"))
        editMenu.addItem(item("Paste", #selector(NSText.paste(_:)), "v"))
        editMenu.addItem(item("Select All", #selector(NSText.selectAll(_:)), "a"))
        for menu in [appMenu, fileMenu, editMenu] {
            let holder = NSMenuItem(); holder.submenu = menu; main.addItem(holder)
        }
        NSApp.mainMenu = main

        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Pouf")
        let menu = NSMenu()
        menu.addItem(item("New Note", #selector(newNoteAction), target: self))
        menu.addItem(item("Show All Notes", #selector(showAll), target: self))
        menu.addItem(onTopItem())
        menu.addItem(.separator())
        menu.addItem(item("Quit Pouf", #selector(NSApplication.terminate(_:))))
        status.menu = menu
        statusItem = status
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
