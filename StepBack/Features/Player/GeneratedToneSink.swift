import AVFAudio
import Foundation
import StepBackCore

actor GeneratedToneSink: ToneSink {
    private let audioSession: PlayerAudioSession
    private let engine = AVAudioEngine()
    private let oscillator = ToneOscillator()
    private let sourceNode: AVAudioSourceNode

    init(audioSession: PlayerAudioSession) {
        self.audioSession = audioSession
        let oscillator = self.oscillator
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            oscillator.render(frameCount: frameCount, audioBufferList: audioBufferList)
            return noErr
        }
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
    }

    func play(_ cue: ToneCue) async {
        guard PlayerPreferences.tonesEnabled else { return }
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                return
            }
        }
        await audioSession.activateCueWindow()
        switch cue {
        case .workStart:
            oscillator.start(frequency: 880, duration: 0.16)
        case let .countdown(value):
            oscillator.start(frequency: value == 1 ? 760 : 620, duration: 0.11)
        case .resumeCountdown:
            oscillator.start(frequency: 620, duration: 0.11)
        }
    }
}

private final class ToneOscillator: @unchecked Sendable {
    private let lock = NSLock()
    private let sampleRate = 44_100.0
    private var phase = 0.0
    private var frequency = 0.0
    private var samplesRemaining = 0

    func start(frequency: Double, duration: Double) {
        lock.withLock {
            self.frequency = frequency
            samplesRemaining = Int(sampleRate * duration)
            phase = 0
        }
    }

    func render(frameCount: AVAudioFrameCount, audioBufferList: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        lock.withLock {
            for frame in 0..<Int(frameCount) {
                let sample: Float
                if samplesRemaining > 0 {
                    let envelope = min(1, Float(samplesRemaining) / Float(sampleRate * 0.02))
                    sample = sin(Float(phase)) * 0.22 * envelope
                    phase += 2 * .pi * frequency / sampleRate
                    samplesRemaining -= 1
                } else {
                    sample = 0
                }
                for buffer in buffers {
                    guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    data[frame] = sample
                }
            }
        }
    }
}
