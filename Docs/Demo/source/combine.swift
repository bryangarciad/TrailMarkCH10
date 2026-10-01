// usage: swift combine.swift out.mp4 clip1.mp4 clip2.mp4 ...
// Concatenates clips onto the first clip's canvas; smaller clips (the watch) are scaled to 70% width and centered.
import AVFoundation
let a = CommandLine.arguments
let clips = a.dropFirst(2).map { AVURLAsset(url: URL(fileURLWithPath: $0)) }
let comp = AVMutableComposition()
var instructions: [AVMutableVideoCompositionInstruction] = []
var canvas = CGSize.zero
var cursor = CMTime.zero
for clip in clips {
    let src = try await clip.loadTracks(withMediaType: .video)[0]
    let size = try await src.load(.naturalSize), dur = try await clip.load(.duration)
    if canvas == .zero { canvas = size }
    let track = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try track.insertTimeRange(CMTimeRange(start: .zero, duration: dur), of: src, at: cursor)
    let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
    if size.width < canvas.width * 0.9 {
        let s = canvas.width * 0.7 / size.width
        layer.setTransform(CGAffineTransform(scaleX: s, y: s).concatenating(CGAffineTransform(
            translationX: (canvas.width - size.width * s) / 2, y: (canvas.height - size.height * s) / 2)), at: cursor)
    }
    let ins = AVMutableVideoCompositionInstruction()
    ins.timeRange = CMTimeRange(start: cursor, duration: dur)
    ins.layerInstructions = [layer]
    ins.backgroundColor = CGColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
    instructions.append(ins)
    cursor = cursor + dur
}
let vc = AVMutableVideoComposition()
vc.renderSize = canvas; vc.frameDuration = CMTime(value: 1, timescale: 30); vc.instructions = instructions
let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)!
ex.videoComposition = vc
let out = URL(fileURLWithPath: a[1]); try? FileManager.default.removeItem(at: out)
try await ex.export(to: out, as: .mp4)
print("ok", cursor.seconds)
