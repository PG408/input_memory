import AppKit

enum StatusBarIcon {
    static let image: NSImage = {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.black.setFill()
        NSColor.black.setStroke()

        let panel = NSBezierPath(roundedRect: NSRect(x: 2.5, y: 3.5, width: 17, height: 16), xRadius: 4, yRadius: 4)
        panel.lineWidth = 2
        panel.stroke()

        let rail = NSBezierPath(roundedRect: NSRect(x: 5.3, y: 6.6, width: 3, height: 9.8), xRadius: 1.5, yRadius: 1.5)
        rail.fill()

        let lineOne = NSBezierPath(roundedRect: NSRect(x: 10.1, y: 13.4, width: 6.6, height: 1.6), xRadius: 0.8, yRadius: 0.8)
        lineOne.fill()

        let lineTwo = NSBezierPath(roundedRect: NSRect(x: 10.1, y: 10.4, width: 5.4, height: 1.4), xRadius: 0.7, yRadius: 0.7)
        lineTwo.fill()

        let connector = NSBezierPath()
        connector.move(to: NSPoint(x: 9.6, y: 7.1))
        connector.line(to: NSPoint(x: 16.2, y: 7.1))
        connector.lineWidth = 1.05
        connector.stroke()

        for x in [9.6, 11.8, 14, 16.2] {
            NSBezierPath(ovalIn: NSRect(x: x - 1, y: 6.1, width: 2, height: 2)).fill()
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }()
}
