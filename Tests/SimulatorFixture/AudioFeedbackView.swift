import AVFAudio
import Foundation
import Observation
import SwiftUI

struct AudioFeedbackView: View {
    @State private var tone = AudioToneOwner()

    var body: some View {
        VStack(spacing: 28) {
            Text("ROAMER AUDIO AUDIT").font(.title).bold()
            Text("\(AudioToneOwner.frequencyHz, specifier: "%.0f") Hz")
                .font(.largeTitle.monospaced())
            Text(tone.playing ? "PLAYING" : "STOPPED")
                .font(.title2.monospaced())
            Text("PLAYS \(tone.playCount)")
                .font(.title2.monospaced())
            HStack(spacing: 24) {
                Button("Start tone") { tone.start() }
                    .disabled(tone.playing)
                Button("Stop tone") { tone.stop() }
                    .disabled(!tone.playing)
            }
        }
        .padding(50)
        .onAppear { tone.record() }
        .onDisappear { tone.stop() }
    }
}

@MainActor
@Observable
private final class AudioToneOwner {
    static let frequencyHz = 997.0

    private static let amplitude: Float = 0.2
    private static let sampleRateHz = 48_000.0

    private let session = UUID().uuidString
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let buffer: AVAudioPCMBuffer
    private let format: AVAudioFormat
    private var connected = false

    private(set) var playing = false
    private(set) var playCount = 0

    init() {
        format = AVAudioFormat(
            standardFormatWithSampleRate: Self.sampleRateHz,
            channels: 2
        )!
        let frames = AVAudioFrameCount(Self.sampleRateHz)
        buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for channelIndex in 0..<Int(format.channelCount) {
            let channel = buffer.floatChannelData![channelIndex]
            for frame in 0..<Int(frames) {
                channel[frame] = Self.amplitude * Float(
                    sin(2 * Double.pi * Self.frequencyHz * Double(frame) / Self.sampleRateHz)
                )
            }
        }
    }

    func start() {
        guard !playing else { return }
        do {
            if !connected {
                engine.attach(player)
                do {
                    try engine.connectNode(player, to: engine.mainMixerNode, format: format)
                    connected = true
                } catch {
                    engine.detach(player)
                    throw error
                }
            }
            player.scheduleBuffer(
                buffer,
                atTime: nil,
                options: .loops,
                completionCallbackType: .dataConsumed,
                completionHandler: nil
            )
            try engine.start()
            try player.playAudio()
            playing = true
            playCount += 1
            record()
        } catch {
            player.stop()
            engine.stop()
            playing = false
            record()
        }
    }

    func stop() {
        guard playing else { return }
        player.stop()
        engine.stop()
        playing = false
        record()
    }

    func record() {
        writeProbeState([
            "session": session,
            "playing": playing,
            "frequencyHz": Self.frequencyHz,
            "playCount": playCount,
            "changedAt": Date().timeIntervalSince1970,
        ], name: "audio.json")
    }
}
