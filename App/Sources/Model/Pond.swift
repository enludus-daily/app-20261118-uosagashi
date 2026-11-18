import Foundation

struct Pos: Hashable, Codable, Sendable {
    var r: Int
    var c: Int
    init(_ r: Int, _ c: Int) {
        self.r = r
        self.c = c
    }
}

/// マスの地形。水草は魚がいない（はじめから見える）。氷は覗いても数が見えない
enum Terrain: Int, Codable, Sendable {
    case water, weed, ice
}

/// マスの見え方
enum CellState: Int, Codable, Sendable {
    /// まだ水面の下
    case hidden
    /// 覗いた（魚はいない）。水が透けて底が見える
    case open
    /// 釣った
    case caught
    /// 覗いて驚かせ、逃げた（糸が 1 本切れた）
    case escaped
}

/// 池の作り（大きさと魚の数と地形）。釣り場の池ごと・今日の池・気ままに、で決まる
struct PondSpec: Codable, Equatable, Sendable {
    var rows: Int
    var cols: Int
    /// 1 匹ぶんの小魚（群れを除く）
    var small: Int
    /// 2 匹ぶんに数えるぬし（大物）
    var big: Int = 0
    /// 横に 3 匹並ぶ群れの数
    var schools: Int = 0
    var weeds: Int = 0
    var ice: Int = 0

    var fishCount: Int { small + big + schools * 3 }
}

/// 池の盤。数（まわり 8 マスの魚の重さの合計）は魚の位置から決まり、変わらない
struct Pond: Codable, Equatable, Sendable {
    let rows: Int
    let cols: Int
    var terrain: [Terrain]
    /// 魚の重さ（0 = いない、1 = 小魚、2 = ぬし）
    var weight: [Int]
    /// 群れの魚か
    var schooled: [Bool]
    var state: [CellState]
    /// 長押しで置いた浮き（「ここは魚」の印）
    var floats: Set<Pos> = []
    /// 桟橋（下の真ん中）。ここから池が開いた状態で始まる
    let pier: Pos

    init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
        terrain = Array(repeating: .water, count: rows * cols)
        weight = Array(repeating: 0, count: rows * cols)
        schooled = Array(repeating: false, count: rows * cols)
        state = Array(repeating: .hidden, count: rows * cols)
        pier = Pos(rows - 1, cols / 2)
    }

    func index(_ p: Pos) -> Int { p.r * cols + p.c }
    func pos(_ i: Int) -> Pos { Pos(i / cols, i % cols) }
    func contains(_ p: Pos) -> Bool { p.r >= 0 && p.r < rows && p.c >= 0 && p.c < cols }

    var allPositions: [Pos] { (0..<(rows * cols)).map(pos) }

    func neighbors(_ p: Pos) -> [Pos] {
        var out: [Pos] = []
        out.reserveCapacity(8)
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                let q = Pos(p.r + dr, p.c + dc)
                if contains(q) { out.append(q) }
            }
        }
        return out
    }

    subscript(_ p: Pos) -> CellState {
        get { state[index(p)] }
        set { state[index(p)] = newValue }
    }

    func terrainAt(_ p: Pos) -> Terrain { terrain[index(p)] }
    func weightAt(_ p: Pos) -> Int { weight[index(p)] }
    func hasFish(_ p: Pos) -> Bool { weight[index(p)] > 0 }

    /// まわり 8 マスの魚の数（ぬしは 2 匹ぶん）
    func number(at p: Pos) -> Int {
        neighbors(p).reduce(0) { $0 + weight[index($1)] }
    }

    /// 覗いたとき数が見えるか（氷の上は見えない）
    func showsNumber(_ p: Pos) -> Bool { terrainAt(p) == .water }

    var totalFish: Int { weight.filter { $0 > 0 }.count }
    var caughtCount: Int { state.filter { $0 == .caught }.count }
    var escapedCount: Int { state.filter { $0 == .escaped }.count }
    /// まだ水の下にいる魚
    var hiddenFish: Int {
        (0..<state.count).filter { state[$0] == .hidden && weight[$0] > 0 }.count
    }
    var hiddenSmall: Int { (0..<state.count).filter { state[$0] == .hidden && weight[$0] == 1 }.count }
    var hiddenBig: Int { (0..<state.count).filter { state[$0] == .hidden && weight[$0] == 2 }.count }
    var isCleared: Bool { hiddenFish == 0 }

    /// 覗いて開く。数が 0 のマスからは、まわりが続けて開く。開いた順と、覗いたマスからの距離（連鎖の時間差）を返す
    @discardableResult
    mutating func open(from start: Pos) -> [(Pos, Int)] {
        guard contains(start), self[start] == .hidden, terrainAt(start) != .weed, !hasFish(start) else { return [] }
        var out: [(Pos, Int)] = []
        var queue: [(Pos, Int)] = [(start, 0)]
        var head = 0
        self[start] = .open
        floats.remove(start)
        while head < queue.count {
            let (p, d) = queue[head]
            head += 1
            out.append((p, d))
            guard showsNumber(p), number(at: p) == 0 else { continue }
            for q in neighbors(p) where self[q] == .hidden && terrainAt(q) != .weed && !hasFish(q) {
                self[q] = .open
                floats.remove(q)
                queue.append((q, d + 1))
            }
        }
        return out
    }
}

// MARK: - 池を作る

extension Pond {
    /// 種から池を作る。桟橋から始めて推理だけで最後まで解けることを、ソルバーで確かめる。
    /// 解けない盤は作り直し、何度やっても作れなければ作りを少しやさしくする（必ず返す）
    static func generate(_ spec: PondSpec, seed: UInt64) -> Pond {
        var rng = SeededRandom(seed: seed)
        var s = spec
        for round in 0..<6 {
            for _ in 0..<40 {
                if let pond = attempt(s, rng: &rng), Solver.solvesFromPier(pond) {
                    return pond
                }
            }
            // やさしくする：氷 → 魚 → 群れの順に減らす
            if s.ice > 0 {
                s.ice = max(0, s.ice - 2)
            } else if s.small > 2 {
                s.small -= 1
            } else if s.schools > 0 {
                s.schools -= 1
            } else if s.big > 0 {
                s.big -= 1
            }
            _ = round
        }
        // ここまで来ることはほぼない（テストで確かめる）。最後は魚の少ない盤
        var tiny = PondSpec(rows: spec.rows, cols: spec.cols, small: 3)
        tiny.weeds = 0
        while true {
            if let pond = attempt(tiny, rng: &rng), Solver.solvesFromPier(pond) { return pond }
        }
    }

    /// 1 回ぶんの盤（解けるかは確かめない）
    static func attempt(_ spec: PondSpec, rng: inout SeededRandom) -> Pond? {
        var pond = Pond(rows: spec.rows, cols: spec.cols)
        let pier = pond.pier
        var safe = Set(pond.neighbors(pier))
        safe.insert(pier)
        var cells = pond.allPositions.filter { !safe.contains($0) }
        rng.shuffle(&cells)
        // 水草（端に寄せすぎない。桟橋のまわりには置かない）
        var placedWeeds = 0
        while placedWeeds < spec.weeds, let p = cells.popLast() {
            pond.terrain[pond.index(p)] = .weed
            placedWeeds += 1
        }
        // 群れ：横に 3 匹
        var schools = 0
        var tries = 0
        while schools < spec.schools && tries < 300 {
            tries += 1
            let r = rng.below(max(1, spec.rows - 2))
            let c = rng.below(max(1, spec.cols - 2))
            let run = (0..<3).map { Pos(r, c + $0) }
            if run.allSatisfy({ pond.contains($0) && !safe.contains($0) && pond.terrainAt($0) == .water && !pond.hasFish($0) }) {
                for p in run {
                    pond.weight[pond.index(p)] = 1
                    pond.schooled[pond.index(p)] = true
                }
                schools += 1
            }
        }
        guard schools == spec.schools else { return nil }
        var free = cells.filter { pond.terrainAt($0) == .water && !pond.hasFish($0) }
        rng.shuffle(&free)
        guard free.count >= spec.big + spec.small + spec.ice else { return nil }
        for _ in 0..<spec.big {
            if let p = free.popLast() { pond.weight[pond.index(p)] = 2 }
        }
        for _ in 0..<spec.small {
            if let p = free.popLast() { pond.weight[pond.index(p)] = 1 }
        }
        // 氷は、魚がいるマスにもいないマスにも張る
        var iceCells = pond.allPositions.filter { !safe.contains($0) && pond.terrainAt($0) == .water }
        rng.shuffle(&iceCells)
        for p in iceCells.prefix(spec.ice) { pond.terrain[pond.index(p)] = .ice }
        pond.open(from: pier)
        return pond
    }
}
