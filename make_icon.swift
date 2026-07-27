import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let canvas = CGSize(width: 1024, height: 1024)
let image = NSImage(size: canvas)

func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
  CGRect(x: x, y: y, width: width, height: height)
}

func roundedPath(_ rect: CGRect, _ radius: CGFloat) -> NSBezierPath {
  NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fill(_ path: NSBezierPath, _ color: NSColor) {
  color.setFill()
  path.fill()
}

func stroke(_ path: NSBezierPath, _ color: NSColor, width: CGFloat) {
  color.setStroke()
  path.lineWidth = width
  path.stroke()
}

image.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high

let bgRect = rect(64, 64, 896, 896)
let bgPath = roundedPath(bgRect, 214)
NSGradient(colors: [
  NSColor(calibratedRed: 0.030, green: 0.036, blue: 0.052, alpha: 1),
  NSColor(calibratedRed: 0.075, green: 0.092, blue: 0.120, alpha: 1)
])?.draw(in: bgPath, angle: -35)

let outerGlow = NSBezierPath(ovalIn: rect(148, 112, 728, 792))
fill(outerGlow, NSColor(calibratedRed: 0.00, green: 0.85, blue: 0.82, alpha: 0.09))

let floorGlow = NSBezierPath(ovalIn: rect(238, 118, 548, 150))
fill(floorGlow, NSColor(calibratedRed: 0.65, green: 1.00, blue: 0.22, alpha: 0.16))

let shadow = NSBezierPath(ovalIn: rect(310, 126, 414, 96))
fill(shadow, NSColor.black.withAlphaComponent(0.34))

let canRect = rect(326, 154, 372, 722)
let canPath = roundedPath(canRect, 86)
NSGradient(colors: [
  NSColor(calibratedRed: 0.015, green: 0.145, blue: 0.165, alpha: 1),
  NSColor(calibratedRed: 0.000, green: 0.640, blue: 0.610, alpha: 1),
  NSColor(calibratedRed: 0.015, green: 0.250, blue: 0.285, alpha: 1)
])?.draw(in: canPath, angle: 0)

stroke(canPath, NSColor.white.withAlphaComponent(0.18), width: 5)

let leftShade = roundedPath(rect(326, 170, 94, 690), 76)
fill(leftShade, NSColor.black.withAlphaComponent(0.17))

let rightShade = roundedPath(rect(606, 178, 64, 678), 54)
fill(rightShade, NSColor.black.withAlphaComponent(0.18))

let highlight = roundedPath(rect(412, 214, 58, 598), 29)
fill(highlight, NSColor.white.withAlphaComponent(0.18))

let thinHighlight = roundedPath(rect(484, 236, 16, 548), 8)
fill(thinHighlight, NSColor.white.withAlphaComponent(0.10))

let topLip = roundedPath(rect(354, 792, 316, 70), 35)
NSGradient(colors: [
  NSColor(calibratedRed: 0.850, green: 1.000, blue: 0.250, alpha: 1),
  NSColor(calibratedRed: 0.210, green: 0.950, blue: 0.800, alpha: 1)
])?.draw(in: topLip, angle: 0)

let bottomLip = roundedPath(rect(354, 174, 316, 68), 34)
NSGradient(colors: [
  NSColor(calibratedRed: 0.010, green: 0.110, blue: 0.130, alpha: 1),
  NSColor(calibratedRed: 0.025, green: 0.270, blue: 0.300, alpha: 1)
])?.draw(in: bottomLip, angle: 0)

let pullTab = NSBezierPath()
pullTab.appendOval(in: rect(458, 812, 110, 30))
fill(pullTab, NSColor(calibratedRed: 0.040, green: 0.120, blue: 0.140, alpha: 0.38))

let boltShadow = NSBezierPath()
boltShadow.move(to: CGPoint(x: 568, y: 708))
boltShadow.line(to: CGPoint(x: 426, y: 486))
boltShadow.line(to: CGPoint(x: 522, y: 486))
boltShadow.line(to: CGPoint(x: 458, y: 316))
boltShadow.line(to: CGPoint(x: 648, y: 566))
boltShadow.line(to: CGPoint(x: 540, y: 566))
boltShadow.close()
fill(boltShadow, NSColor.black.withAlphaComponent(0.28))

let bolt = NSBezierPath()
bolt.move(to: CGPoint(x: 556, y: 724))
bolt.line(to: CGPoint(x: 416, y: 500))
bolt.line(to: CGPoint(x: 516, y: 500))
bolt.line(to: CGPoint(x: 450, y: 324))
bolt.line(to: CGPoint(x: 642, y: 582))
bolt.line(to: CGPoint(x: 532, y: 582))
bolt.close()
NSGradient(colors: [
  NSColor(calibratedRed: 1.000, green: 1.000, blue: 0.350, alpha: 1),
  NSColor(calibratedRed: 0.670, green: 1.000, blue: 0.160, alpha: 1)
])?.draw(in: bolt, angle: -20)
stroke(bolt, NSColor(calibratedRed: 0.010, green: 0.180, blue: 0.180, alpha: 0.92), width: 11)

let rim = roundedPath(bgRect.insetBy(dx: 7, dy: 7), 208)
stroke(rim, NSColor.white.withAlphaComponent(0.10), width: 4)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
  fatalError("Failed to render icon")
}

try png.write(to: outputURL)
