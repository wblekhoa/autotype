// Sinh AutoType.icns bằng code — không cần file thiết kế ngoài.
// Chạy: swift make-icon.swift    (chỉ maintainer cần, kết quả đã commit sẵn)
import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let fm = FileManager.default
let iconset = "AutoType.iconset"
try? fm.removeItem(atPath: iconset)
try! fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

func draw(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(px)

    // nền bo góc kiểu squircle, chừa lề như icon macOS chuẩn
    let inset = s * 0.055
    let rect = CGRect(x: inset, y: inset, width: s - inset*2, height: s - inset*2)
    let path = CGPath(roundedRect: rect, cornerWidth: s * 0.225, cornerHeight: s * 0.225, transform: nil)
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs, colors: [
        CGColor(red: 0.30, green: 0.36, blue: 0.92, alpha: 1),
        CGColor(red: 0.14, green: 0.16, blue: 0.52, alpha: 1)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
    ctx.restoreGState()

    // dãy phím: 3 hàng, hàng cuối là phím dài (space)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    let kw = s * 0.148, kh = s * 0.115, gap = s * 0.038
    let rowW = kw*4 + gap*3
    let startX = (s - rowW) / 2
    let startY = s * 0.615
    for row in 0..<2 {
        for col in 0..<4 {
            let r = CGRect(x: startX + CGFloat(col)*(kw+gap),
                           y: startY - CGFloat(row)*(kh+gap), width: kw, height: kh)
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: s*0.028, cornerHeight: s*0.028, transform: nil))
        }
    }
    let spaceW = rowW * 0.72
    let sp = CGRect(x: (s - spaceW)/2, y: startY - 2*(kh+gap), width: spaceW, height: kh)
    ctx.addPath(CGPath(roundedRect: sp, cornerWidth: s*0.028, cornerHeight: s*0.028, transform: nil))
    ctx.fillPath()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for sz in sizes {
    let d = draw(sz)
    if sz <= 512 { try! d.write(to: URL(fileURLWithPath: "\(iconset)/icon_\(sz)x\(sz).png")) }
    if sz >= 32  { try! d.write(to: URL(fileURLWithPath: "\(iconset)/icon_\(sz/2)x\(sz/2)@2x.png")) }
}
print("đã sinh \(iconset)")
