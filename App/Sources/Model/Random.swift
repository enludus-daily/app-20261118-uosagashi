import Foundation

/// 決まった種で毎回同じ並びを作る乱数（今日の池・撮影・テスト）。端末が違っても同じ盤になる
struct SeededRandom: RandomNumberGenerator, Sendable, Codable, Equatable {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    // 保存は文字列で（大きな整数を JSON の数にすると、読み戻すときに桁が丸められることがある）
    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        state = UInt64(text) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(String(state))
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0..<n（n > 0）
    mutating func below(_ n: Int) -> Int { Int(next() % UInt64(max(n, 1))) }

    /// 0...1
    mutating func unit() -> Double { Double(next() % 1_000_001) / 1_000_000 }

    /// 端末によらず同じになる並べ替え（Fisher–Yates）
    mutating func shuffle<T>(_ a: inout [T]) {
        guard a.count > 1 else { return }
        for i in stride(from: a.count - 1, to: 0, by: -1) {
            a.swapAt(i, below(i + 1))
        }
    }
}

enum Seeds {
    /// 日付から作る種（今日の池は、だれが開いても同じ盤）
    static func daily(_ dayKey: String) -> UInt64 {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        for b in ("uosagashi-" + dayKey).utf8 {
            h ^= UInt64(b)
            h = h &* 0x0000_0100_0000_01B3
        }
        return h
    }

    static func level(_ area: Area, _ index: Int) -> UInt64 {
        daily("level-\(area.rawValue)-\(index)")
    }
}
