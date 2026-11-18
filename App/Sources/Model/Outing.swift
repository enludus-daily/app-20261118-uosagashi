import Foundation

/// どの池で遊んでいるか
enum OutingKind: Codable, Equatable, Hashable, Sendable {
    /// 今日の池（日付の種。1 日 1 回）
    case daily(String)
    /// 釣り場の n 番目の池
    case level(Area, Int)
    /// 気ままに（大きさ 0〜2）
    case free(Int)
    /// はじめての池（案内つき）
    case tutorial

    var area: Area {
        switch self {
        case .level(let a, _): a
        default: .village
        }
    }
}

/// 釣った 1 匹
struct Catch: Codable, Equatable, Hashable, Sendable {
    var speciesID: String
    var cm: Double
    var pos: Pos
    var species: Species? { Species.find(speciesID) }
}

/// 1 回の釣り（1 つの池を、糸が尽きるか魚がいなくなるまで）
struct Outing: Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable {
        case playing
        /// 水の下の魚がいなくなった（釣ったか逃げた）
        case cleared
        /// 糸が尽きた
        case snapped
    }

    /// 1 回の操作で起きたこと（画面の動き・振動・音を決める）
    enum Event: Equatable {
        case none
        /// 覗いて開いた（マスと、覗いた所からの距離）
        case opened([Pos: Int])
        /// 魚のいるマスを覗いて、驚かせて逃がした
        case scared(Pos)
        case caught(Catch)
        /// 魚のいないマスに竿を垂らした（糸が切れ、マスは開く）
        case missed(Pos, [Pos: Int])
    }

    let kind: OutingKind
    let seed: UInt64
    var pond: Pond
    static let maxLines = 3
    var lines = Outing.maxLines
    var hintsLeft: Int
    var catches: [Catch] = []
    var status: Status = .playing
    var seconds: Int = 0
    var moves: Int = 0
    var hintsUsed: Int = 0

    var area: Area { kind.area }
    var isOver: Bool { status != .playing }
    var linesLost: Int { Outing.maxLines - lines }

    /// 星：糸を切らずに全部 3、1 本 2、それ以外で池を空にした 1、糸が尽きた 0
    var stars: Int {
        guard status == .cleared else { return 0 }
        return max(1, 3 - linesLost)
    }

    init(kind: OutingKind, seed: UInt64, spec: PondSpec, hints: Int) {
        self.kind = kind
        self.seed = seed
        pond = Pond.generate(spec, seed: seed)
        hintsLeft = hints
    }

    init(kind: OutingKind, seed: UInt64, pond: Pond, hints: Int) {
        self.kind = kind
        self.seed = seed
        self.pond = pond
        hintsLeft = hints
    }

    /// のこりの魚（ぬしと小魚）
    var hiddenFish: Int { pond.hiddenFish }
    var totalFish: Int { pond.totalFish }

    // MARK: - 操作

    /// 覗く
    mutating func peek(_ p: Pos) -> Event {
        guard status == .playing, pond.contains(p), pond[p] == .hidden, pond.terrainAt(p) != .weed else { return .none }
        // 浮きを置いたマスは、覗かない（間違えて驚かせないように）
        guard !pond.floats.contains(p) else { return .none }
        moves += 1
        if pond.hasFish(p) {
            pond[p] = .escaped
            pond.floats.remove(p)
            loseLine()
            finishIfDone()
            return .scared(p)
        }
        let opened = pond.open(from: p)
        finishIfDone()
        return .opened(Dictionary(opened, uniquingKeysWith: { a, _ in a }))
    }

    /// 竿を垂らす
    mutating func cast(_ p: Pos) -> Event {
        guard status == .playing, pond.contains(p), pond[p] == .hidden, pond.terrainAt(p) != .weed else { return .none }
        moves += 1
        pond.floats.remove(p)
        if pond.hasFish(p) {
            pond[p] = .caught
            let i = pond.index(p)
            let key = schoolKey(p)
            let (sp, cm) = Species.assign(area: area, seed: seed, index: i, weight: pond.weight[i], schooled: pond.schooled[i], schoolKey: key)
            let c = Catch(speciesID: sp.id, cm: cm, pos: p)
            catches.append(c)
            finishIfDone()
            return .caught(c)
        }
        let opened = pond.open(from: p)
        loseLine()
        finishIfDone()
        return .missed(p, Dictionary(opened, uniquingKeysWith: { a, _ in a }))
    }

    /// 浮きを置く・外す
    mutating func toggleFloat(_ p: Pos) -> Bool {
        guard status == .playing, pond.contains(p), pond[p] == .hidden, pond.terrainAt(p) != .weed else { return false }
        if pond.floats.contains(p) {
            pond.floats.remove(p)
        } else {
            pond.floats.insert(p)
        }
        return true
    }

    /// ヒント（推理で分かるマスを 1 つ）。使える回数を 1 減らす
    mutating func useHint() -> (Pos, isFish: Bool)? {
        guard status == .playing, hintsLeft > 0, let h = Solver.hint(pond) else { return nil }
        hintsLeft -= 1
        hintsUsed += 1
        return h
    }

    /// 群れの 3 匹を同じ種にするための鍵（群れの左端のマス）
    private func schoolKey(_ p: Pos) -> Int {
        guard pond.schooled[pond.index(p)] else { return pond.index(p) }
        var c = p.c
        // 左へたどる（群れは 3 匹なので、左端は c - (c - start) % 3 では決まらない。並んだ群れの左端まで）
        while c - 1 >= 0 && pond.schooled[pond.index(Pos(p.r, c - 1))] { c -= 1 }
        let run = p.c - c
        return pond.index(Pos(p.r, c + (run / 3) * 3))
    }

    private mutating func loseLine() {
        lines = max(0, lines - 1)
    }

    private mutating func finishIfDone() {
        if pond.isCleared {
            status = .cleared
        } else if lines == 0 {
            status = .snapped
        }
    }

    /// 糸が尽きたあと、残りの魚を見せる（逃げていく）
    var remainingFishPositions: [Pos] {
        pond.allPositions.filter { pond[$0] == .hidden && pond.hasFish($0) }
    }

    /// いちばん大きい 1 匹（共有カード）
    var bestCatch: Catch? {
        catches.max { a, b in
            let ra = (a.cm - Double(a.species?.minCm ?? 0)) / Double(max(1, (a.species?.maxCm ?? 1) - (a.species?.minCm ?? 0)))
            let rb = (b.cm - Double(b.species?.minCm ?? 0)) / Double(max(1, (b.species?.maxCm ?? 1) - (b.species?.minCm ?? 0)))
            return (a.species?.isLunker == true ? 1 : 0, ra) < (b.species?.isLunker == true ? 1 : 0, rb)
        }
    }
}

// MARK: - 池の作り（今日の池・気ままに・はじめて）

enum Ponds {
    static func dailySpec(_ dayKey: String) -> PondSpec {
        // 曜日で少しずつ変える（同じ日はだれでも同じ）
        var rng = SeededRandom(seed: Seeds.daily(dayKey) ^ 0xD1CE)
        let variants: [PondSpec] = [
            PondSpec(rows: 10, cols: 9, small: 9, big: 2, schools: 1, weeds: 3),
            PondSpec(rows: 11, cols: 9, small: 11, big: 2, schools: 1, weeds: 4),
            PondSpec(rows: 10, cols: 9, small: 8, big: 3, schools: 1, weeds: 2),
            PondSpec(rows: 11, cols: 9, small: 9, big: 2, schools: 2, weeds: 3),
        ]
        return variants[rng.below(variants.count)]
    }

    static func freeSpec(_ size: Int) -> PondSpec {
        switch size {
        case 0: PondSpec(rows: 8, cols: 8, small: 7, big: 1, weeds: 2)
        case 1: PondSpec(rows: 10, cols: 9, small: 9, big: 2, schools: 1, weeds: 3)
        default: PondSpec(rows: 11, cols: 9, small: 11, big: 4, schools: 2, weeds: 3)
        }
    }

    static let tutorialSpec = PondSpec(rows: 7, cols: 7, small: 4)
    static let tutorialSeed: UInt64 = 20_261_118
}
