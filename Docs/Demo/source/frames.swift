import AVFoundation
import AppKit
let args = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.maximumSize = CGSize(width: 360, height: 780)
gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
let dur = try await asset.load(.duration)
print("duration", dur.seconds)
var imgs: [CGImage] = []
for t in args[3].split(separator: ",").compactMap({ Double($0) }) {
    if let (img, _) = try? await gen.image(at: CMTime(seconds: t, preferredTimescale: 600)) { imgs.append(img) }
}
// contact sheet
let w = imgs.first!.width, h = imgs.first!.height, cols = min(imgs.count, 6), rows = (imgs.count + cols - 1) / cols
let ctx = CGContext(data: nil, width: w * cols, height: h * rows, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
for (i, img) in imgs.enumerated() {
    ctx.draw(img, in: CGRect(x: (i % cols) * w, y: (rows - 1 - i / cols) * h, width: w, height: h))
}
let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
