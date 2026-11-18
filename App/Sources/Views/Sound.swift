import AVFoundation

/// 効果音（端末の中で作る。録音したファイルは持たない）。
/// 池の音：覗くと「ちゃぽん」、連鎖は水滴が続く、釣れると水しぶき、ぬしは低く大きく、糸が切れると「ぷつん」。
/// 消音スイッチに従い、ほかのアプリの音と混ぜる（.ambient）
@MainActor
final class SoundBox {
    static let shared = SoundBox()

    enum Cue: Hashable {
        case peek, chain, float, catchFish, lunker, snap, hint, start, fanfare, sad
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var nextPlayer = 0
    private var prepared = false
    private let rate = 44_100.0
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)

    /// 音量の段階（五十音マインスイーパーの段階にならう：触る 0.4・開く 0.6・当たり 0.8）
    private func volume(_ cue: Cue) -> Float {
        switch cue {
        case .float, .hint: 0.4
        case .peek, .chain, .start: 0.6
        case .snap, .sad: 0.7
        case .catchFish, .lunker, .fanfare: 0.8
        }
    }

    private func prepare() -> Bool {
        if prepared { return engine.isRunning || ((try? engine.start()) != nil) }
        guard let format else { return false }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        prepared = true
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    func play(_ cue: Cue) {
        guard prepare(), engine.isRunning else { return }
        let buffer: AVAudioPCMBuffer
        if let b = buffers[cue] {
            buffer = b
        } else {
            guard let b = make(cue) else { return }
            buffers[cue] = b
            buffer = b
        }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.volume = volume(cue)
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    // MARK: - 音を作る

    private struct Partial {
        var freq: Double
        var amp: Double
        var decay: Double
        var delay: Double = 0
        var sweepTo: Double? = nil
    }

    private func make(_ cue: Cue) -> AVAudioPCMBuffer? {
        switch cue {
        case .peek:
            // ちゃぽん：高い音が下がる＋小さな泡
            return synth(0.22, noise: 0.05, noiseDecay: 40, partials: [Partial(freq: 1300, amp: 0.55, decay: 18, sweepTo: 520), Partial(freq: 2600, amp: 0.15, decay: 30, sweepTo: 1100)])
        case .chain:
            return synth(0.5, noise: 0.04, noiseDecay: 20, partials: (0..<5).map { i in
                Partial(freq: 1500 - Double(i) * 120, amp: 0.4, decay: 22, delay: Double(i) * 0.055, sweepTo: 700 - Double(i) * 60)
            })
        case .float:
            return synth(0.12, noise: 0, partials: [Partial(freq: 880, amp: 0.4, decay: 30, sweepTo: 990), Partial(freq: 1760, amp: 0.1, decay: 40)])
        case .catchFish:
            // 水しぶき＋上がる 2 音
            return synth(0.55, noise: 0.45, noiseDecay: 9, partials: [Partial(freq: 784, amp: 0.4, decay: 7, delay: 0.08), Partial(freq: 1175, amp: 0.35, decay: 7, delay: 0.18)])
        case .lunker:
            return synth(0.9, noise: 0.6, noiseDecay: 5, partials: [Partial(freq: 140, amp: 0.6, decay: 5, sweepTo: 90), Partial(freq: 587, amp: 0.35, decay: 4, delay: 0.2), Partial(freq: 880, amp: 0.35, decay: 4, delay: 0.32), Partial(freq: 1175, amp: 0.3, decay: 4, delay: 0.44)])
        case .snap:
            // ぷつん：短い高い音と低いどすん
            return synth(0.4, noise: 0.25, noiseDecay: 30, partials: [Partial(freq: 2200, amp: 0.4, decay: 60), Partial(freq: 110, amp: 0.6, decay: 9, delay: 0.04, sweepTo: 70)])
        case .hint:
            return synth(0.45, noise: 0, partials: [Partial(freq: 1046, amp: 0.3, decay: 8), Partial(freq: 1568, amp: 0.25, decay: 8, delay: 0.09)])
        case .start:
            return synth(0.6, noise: 0.15, noiseDecay: 6, partials: [Partial(freq: 520, amp: 0.4, decay: 6, sweepTo: 300), Partial(freq: 660, amp: 0.2, decay: 6, delay: 0.1)])
        case .fanfare:
            let notes = [523.3, 659.3, 784.0, 1046.5]
            return synth(1.2, noise: 0.08, noiseDecay: 6, partials: notes.enumerated().flatMap { i, f in
                [Partial(freq: f, amp: 0.4, decay: 4, delay: Double(i) * 0.12), Partial(freq: f * 2, amp: 0.1, decay: 6, delay: Double(i) * 0.12)]
            })
        case .sad:
            return synth(0.9, noise: 0.1, noiseDecay: 4, partials: [Partial(freq: 440, amp: 0.4, decay: 4, sweepTo: 330), Partial(freq: 349, amp: 0.3, decay: 4, delay: 0.25, sweepTo: 262)])
        }
    }

    private func synth(_ seconds: Double, noise: Double, noiseDecay: Double = 60, partials: [Partial]) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let frames = AVAudioFrameCount(seconds * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        var rng = SeededRandom(seed: 42)
        var phases = Array(repeating: 0.0, count: partials.count)
        for i in 0..<Int(frames) {
            let t = Double(i) / rate
            var v = 0.0
            for (k, p) in partials.enumerated() where t >= p.delay {
                let local = t - p.delay
                var f = p.freq
                if let to = p.sweepTo { f = p.freq + (to - p.freq) * min(1, local / seconds) }
                phases[k] += 2 * .pi * f / rate
                // 立ち上がりを 3ms でならす（ぷつっと鳴らない）
                let attack = min(1, local / 0.003)
                v += sin(phases[k]) * p.amp * exp(-local * p.decay) * attack
            }
            if noise > 0 {
                let n = Double(rng.next() % 20_000) / 10_000 - 1
                v += n * noise * exp(-t * noiseDecay)
            }
            // 終わりを 10ms でならす
            let tail = min(1, (seconds - t) / 0.01)
            data[i] = Float(max(-1, min(1, v * tail)))
        }
        return buffer
    }
}
