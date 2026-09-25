import AppKit

// Exact vector wave mark from the supplied sign-in design; render each icon size
// independently so Finder's small icons never depend on a scaled-up bitmap.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = try String(contentsOf: root.appendingPathComponent("assets/AppIcon/CoveWaves.svg"), encoding: .utf8)
let pattern = try NSRegularExpression(pattern: "d=\"([^\"]+)\"")
let match = pattern.firstMatch(in: source, range: NSRange(source.startIndex..., in: source))!
let data = String(source[Range(match.range(at: 1), in: source)!])
let tokensPattern = try NSRegularExpression(pattern: "[MmQqZz]|[-+]?(?:[0-9]*\\.)?[0-9]+")
let tokens = tokensPattern.matches(in: data, range: NSRange(data.startIndex..., in: data))
  .map { String(data[Range($0.range, in: data)!]) }
let mark = CGMutablePath()
var index = 0
var command = "M"
var current = CGPoint.zero
var start = CGPoint.zero
func number() -> CGFloat {
  defer { index += 1 }
  return CGFloat(Double(tokens[index])!)
}
while index < tokens.count {
  if tokens[index].first!.isLetter {
    command = tokens[index]
    index += 1
  }
  switch command {
  case "M", "m":
    let x = number(), y = number()
    current = command == "m" ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
    start = current
    mark.move(to: current)
  case "q", "Q":
    let x1 = number(), y1 = number(), x = number(), y = number()
    let control = command == "q" ? CGPoint(x: current.x + x1, y: current.y + y1) : CGPoint(x: x1, y: y1)
    current = command == "q" ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
    mark.addQuadCurve(to: current, control: control)
  case "z", "Z":
    mark.closeSubpath()
    current = start
  default: fatalError("Unsupported wave path command")
  }
}

let output = root.appendingPathComponent("assets/AppIcon/Cove.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
func gray(_ value: CGFloat, alpha: CGFloat = 1) -> CGColor {
  CGColor(colorSpace: colorSpace, components: [value, value, value, alpha])!
}
func render(_ pixels: Int, to url: URL) throws {
  let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
    bytesPerRow: pixels * 4, space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  let scale = CGFloat(pixels) / 1024
  context.scaleBy(x: scale, y: scale)
  context.translateBy(x: 0, y: 1024)
  context.scaleBy(x: 1, y: -1)
  let tile = CGPath(roundedRect: CGRect(x: 64, y: 64, width: 896, height: 896),
    cornerWidth: 200, cornerHeight: 200, transform: nil)
  context.saveGState()
  context.setShadow(offset: CGSize(width: 0, height: -9), blur: 14, color: gray(0, alpha: 0.22))
  context.addPath(tile)
  context.setFillColor(gray(0.19))
  context.fillPath()
  context.restoreGState()
  context.saveGState()
  context.addPath(tile)
  context.clip()
  let surface = CGGradient(colorsSpace: colorSpace,
    colors: [gray(0.23), gray(0.13)] as CFArray, locations: [0, 1])!
  context.drawLinearGradient(surface, start: CGPoint(x: 512, y: 64),
    end: CGPoint(x: 512, y: 960), options: [])
  context.restoreGState()
  context.translateBy(x: 204, y: 204)
  context.scaleBy(x: 44, y: 44)
  context.addPath(mark)
  context.setFillColor(gray(0.98))
  context.fillPath()
  let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
  try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}
for size in [16, 32, 128, 256, 512] {
  try render(size, to: output.appendingPathComponent("icon_\(size)x\(size).png"))
  try render(size * 2, to: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(1024, to: root.appendingPathComponent("assets/AppIcon/CoveIcon.png"))
print("Rendered Cove icon at all macOS sizes.")
