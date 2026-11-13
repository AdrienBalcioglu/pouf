import AppKit
// Draws the app icon: a yellow sticky note whose right side is turning to dust.
let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
let note = NSRect(x: 150, y: 170, width: 640, height: 640)
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: NSColor.black.withAlphaComponent(0.28).cgColor)
NSColor(red: 1.0, green: 0.89, blue: 0.36, alpha: 1).setFill()
NSBezierPath(roundedRect: note, xRadius: 56, yRadius: 56).fill()
ctx.setShadow(offset: .zero, blur: 0, color: nil)
NSColor(red: 0.98, green: 0.80, blue: 0.22, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: note.minX, y: note.maxY - 120, width: note.width, height: 120), xRadius: 56, yRadius: 56).fill()
NSRect(x: note.minX, y: note.maxY - 120, width: note.width, height: 60).fill()
NSColor(red: 0.45, green: 0.36, blue: 0.08, alpha: 0.55).setFill()
for (i, w) in [420.0, 340.0, 380.0].enumerated() {
    NSBezierPath(roundedRect: NSRect(x: note.minX + 70, y: note.maxY - 230 - CGFloat(i) * 105, width: CGFloat(w), height: 34), xRadius: 17, yRadius: 17).fill()
}
// Dust: squares leaving the right edge, smaller and fainter as they go.
var seed: UInt64 = 42
func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) % 1000) / 1000 }
for _ in 0..<150 {
    let t = rnd()
    let x = note.maxX - 90 + t * 280, y = note.minY + 60 + rnd() * 560 + t * 90
    let s = 40 * (1 - t) + 8
    NSColor(red: 1.0, green: 0.86 + rnd() * 0.06, blue: 0.30, alpha: 1 - t * 0.85).setFill()
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: s, height: s), xRadius: 5, yRadius: 5).fill()
}
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
