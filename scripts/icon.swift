import AppKit
let destination = CommandLine.arguments[1]
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let background = NSBezierPath(roundedRect: NSRect(x: 24, y: 24, width: 976, height: 976), xRadius: 220, yRadius: 220)
let gradient = NSGradient(starting: NSColor(calibratedRed: 0.31, green: 0.19, blue: 0.14, alpha: 1), ending: NSColor(calibratedRed: 0.64, green: 0.38, blue: 0.22, alpha: 1))!
gradient.draw(in: background, angle: 70)
NSColor(calibratedWhite: 1, alpha: 0.06).setFill()
NSBezierPath(ovalIn: NSRect(x: 80, y: 80, width: 864, height: 864)).fill()
let cream = NSColor(calibratedRed: 1, green: 0.92, blue: 0.79, alpha: 1)
cream.setStroke()
let handle = NSBezierPath(ovalIn: NSRect(x: 621, y: 340, width: 185, height: 215)); handle.lineWidth = 47; handle.stroke()
cream.setFill()
let cup = NSBezierPath()
cup.move(to: NSPoint(x: 252, y: 595)); cup.line(to: NSPoint(x: 677, y: 595)); cup.line(to: NSPoint(x: 655, y: 343))
cup.curve(to: NSPoint(x: 477, y: 257), controlPoint1: NSPoint(x: 646, y: 276), controlPoint2: NSPoint(x: 542, y: 257))
cup.curve(to: NSPoint(x: 274, y: 343), controlPoint1: NSPoint(x: 393, y: 257), controlPoint2: NSPoint(x: 285, y: 271))
cup.close(); cup.fill()
let saucer = NSBezierPath(); saucer.move(to: NSPoint(x: 220, y: 230)); saucer.line(to: NSPoint(x: 735, y: 230)); saucer.lineWidth = 32; saucer.lineCapStyle = .round; saucer.stroke()
for x in [365.0, 485.0, 605.0] {
    let steam = NSBezierPath(); steam.move(to: NSPoint(x: x, y: 663))
    steam.curve(to: NSPoint(x: x + 4, y: 805), controlPoint1: NSPoint(x: x - 65, y: 723), controlPoint2: NSPoint(x: x + 66, y: 754))
    steam.lineWidth = 27; steam.lineCapStyle = .round; steam.stroke()
}
NSColor(calibratedRed: 0.44, green: 0.26, blue: 0.17, alpha: 1).setStroke()
let clock = NSBezierPath(ovalIn: NSRect(x: 403, y: 365, width: 140, height: 140)); clock.lineWidth = 10; clock.stroke()
let hands = NSBezierPath(); hands.move(to: NSPoint(x: 473, y: 478)); hands.line(to: NSPoint(x: 473, y: 435)); hands.line(to: NSPoint(x: 503, y: 415)); hands.lineWidth = 10; hands.lineCapStyle = .round; hands.lineJoinStyle = .round; hands.stroke()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
