import Foundation

/// 推理だけで分かることを探す（盤を作るときの「解けるか」の確かめと、ヒント）。
/// 見えている数と、もう分かっている魚（釣った・逃げた）と、残りの魚の数だけを使う。答え（魚の位置）は見ない
enum Solver {
    /// 推理の結果
    struct Deduction: Equatable {
        /// 魚がいないと決まるマス（覗いてよい）
        var safe: [Pos] = []
        /// 魚がいると決まるマス（釣ってよい）
        var fish: [Pos] = []
        var isEmpty: Bool { safe.isEmpty && fish.isEmpty }
    }

    /// 見えていること
    struct Knowledge {
        let rows: Int
        let cols: Int
        let terrain: [Terrain]
        /// 開いたマス（数が見える水のマス、または氷）
        var open: [Bool]
        /// 分かっている魚の重さ（0 = 分からない・いない）
        var knownFish: [Int]
        /// 開いた水のマスの数
        var numbers: [Int]
        /// まだ分かっていない小魚・ぬしの数
        var remainingSmall: Int
        var remainingBig: Int

        func isUnknown(_ i: Int) -> Bool { !open[i] && knownFish[i] == 0 && terrain[i] != .weed }
    }

    static func knowledge(of pond: Pond) -> Knowledge {
        let n = pond.rows * pond.cols
        var open = Array(repeating: false, count: n)
        var known = Array(repeating: 0, count: n)
        var numbers = Array(repeating: 0, count: n)
        for i in 0..<n {
            switch pond.state[i] {
            case .open:
                open[i] = true
                if pond.terrain[i] == .water { numbers[i] = pond.number(at: pond.pos(i)) }
            case .caught, .escaped:
                known[i] = pond.weight[i]
            case .hidden:
                break
            }
        }
        return Knowledge(rows: pond.rows, cols: pond.cols, terrain: pond.terrain, open: open, knownFish: known,
                         numbers: numbers, remainingSmall: pond.hiddenSmall, remainingBig: pond.hiddenBig)
    }

    // MARK: - 解けるか

    /// 桟橋から始めて、推理だけで全部の魚が分かるか
    static func solvesFromPier(_ pond: Pond) -> Bool {
        var p = pond
        var guardSteps = 0
        while p.hiddenFish > 0 {
            guardSteps += 1
            if guardSteps > p.rows * p.cols * 2 { return false }
            let d = deduce(knowledge(of: p))
            if d.isEmpty { return false }
            for s in d.safe { p.open(from: s) }
            for f in d.fish where p[f] == .hidden { p[f] = .caught }
        }
        return true
    }

    /// いま分かることを 1 つ（ヒント）。魚がいないマスを先に（覗く方が安全なので）
    static func hint(_ pond: Pond) -> (Pos, isFish: Bool)? {
        let d = deduce(knowledge(of: pond))
        // 浮きを置いていないマスを先に
        if let s = d.safe.first(where: { !pond.floats.contains($0) }) ?? d.safe.first { return (s, false) }
        if let f = d.fish.first { return (f, true) }
        return nil
    }

    // MARK: - 推理

    private struct Constraint {
        var cells: [Int]
        var target: Int
    }

    private struct TooMany: Error {}

    static func deduce(_ k: Knowledge) -> Deduction {
        let n = k.rows * k.cols
        func nbrs(_ i: Int) -> [Int] {
            let r = i / k.cols, c = i % k.cols
            var out: [Int] = []
            for dr in -1...1 {
                for dc in -1...1 where !(dr == 0 && dc == 0) {
                    let rr = r + dr, cc = c + dc
                    if rr >= 0 && rr < k.rows && cc >= 0 && cc < k.cols { out.append(rr * k.cols + cc) }
                }
            }
            return out
        }
        var constraints: [Constraint] = []
        for i in 0..<n where k.open[i] && k.terrain[i] == .water {
            let ns = nbrs(i)
            let unknown = ns.filter { k.isUnknown($0) }
            if unknown.isEmpty { continue }
            let known = ns.reduce(0) { $0 + k.knownFish[$1] }
            constraints.append(Constraint(cells: unknown, target: k.numbers[i] - known))
        }
        let weights: [Int] = k.remainingBig > 0 ? [1, 2] : [1]
        let allUnknown = (0..<n).filter { k.isUnknown($0) }
        if allUnknown.isEmpty { return Deduction() }

        // 1) つながった塊ごとに、ありうる並びを全部数える
        var frontierSet = Set<Int>()
        for c in constraints { frontierSet.formUnion(c.cells) }
        let frontier = frontierSet.sorted()
        var parent = Dictionary(uniqueKeysWithValues: frontier.map { ($0, $0) })
        func find(_ x: Int) -> Int {
            var x = x
            while let p = parent[x], p != x {
                parent[x] = parent[p] ?? p
                x = p
            }
            return x
        }
        for c in constraints {
            guard let first = c.cells.first else { continue }
            for u in c.cells.dropFirst() {
                let a = find(u), b = find(first)
                if a != b { parent[a] = b }
            }
        }
        var groups: [Int: [Int]] = [:]
        for f in frontier { groups[find(f), default: []].append(f) }

        var result = Deduction()
        let toPos = { (i: Int) in Pos(i / k.cols, i % k.cols) }
        for group in groups.values.sorted(by: { ($0.first ?? 0) < ($1.first ?? 0) }) {
            let set = Set(group)
            let sub = constraints.filter { set.contains($0.cells[0]) }
            guard let e = try? enumerate(cells: group, constraints: sub, weights: weights, global: nil), e.solutions > 0 else { continue }
            for (j, cell) in group.enumerated() {
                if !e.canFish[j] { result.safe.append(toPos(cell)) } else if !e.canEmpty[j] { result.fish.append(toPos(cell)) }
            }
        }
        if !result.isEmpty { return result }

        // 2) 残りの魚の数も使って、全体で数える（塊が小さいときだけ）
        guard frontier.count <= 28 else { return result }
        let interior = allUnknown.filter { !frontierSet.contains($0) }
        let global = Global(small: k.remainingSmall, big: k.remainingBig, interior: interior.count)
        guard let e = try? enumerate(cells: frontier, constraints: constraints, weights: weights, global: global) else { return result }
        if e.solutions == 0 { return result }
        for (j, cell) in frontier.enumerated() {
            if !e.canFish[j] { result.safe.append(toPos(cell)) } else if !e.canEmpty[j] { result.fish.append(toPos(cell)) }
        }
        if !interior.isEmpty {
            if e.interiorFish == [0] {
                result.safe += interior.map(toPos)
            } else if e.interiorFish == [interior.count] {
                result.fish += interior.map(toPos)
            }
        }
        return result
    }

    private struct Global {
        var small: Int
        var big: Int
        var interior: Int
    }

    private struct Enumeration {
        var canEmpty: [Bool]
        var canFish: [Bool]
        var solutions = 0
        var interiorFish = Set<Int>()
    }

    private static func enumerate(cells: [Int], constraints: [Constraint], weights: [Int], global: Global?) throws -> Enumeration {
        var index: [Int: Int] = [:]
        for (j, c) in cells.enumerated() { index[c] = j }
        let cons: [(cells: [Int], target: Int)] = constraints.map { c in (c.cells.compactMap { index[$0] }, c.target) }
        var byCell = Array(repeating: [Int](), count: cells.count)
        for (ci, c) in cons.enumerated() {
            for u in c.cells { byCell[u].append(ci) }
        }
        let maxW = weights.max() ?? 1
        var value = Array(repeating: -1, count: cells.count)
        var out = Enumeration(canEmpty: Array(repeating: false, count: cells.count), canFish: Array(repeating: false, count: cells.count))
        var nodes = 0

        func consistent(_ ci: Int) -> Bool {
            let c = cons[ci]
            var sum = 0, free = 0
            for u in c.cells {
                if value[u] < 0 { free += 1 } else { sum += value[u] }
            }
            return sum <= c.target && sum + free * maxW >= c.target
        }

        func rec(_ i: Int) throws {
            nodes += 1
            if nodes > 200_000 { throw TooMany() }
            if i == cells.count {
                if let g = global {
                    var s1 = 0, b1 = 0
                    for v in value {
                        if v == 1 { s1 += 1 } else if v == 2 { b1 += 1 }
                    }
                    let rs = g.small - s1, rb = g.big - b1
                    if rs < 0 || rb < 0 || rs + rb > g.interior { return }
                    out.interiorFish.insert(rs + rb)
                }
                out.solutions += 1
                for (u, v) in value.enumerated() {
                    if v == 0 { out.canEmpty[u] = true } else { out.canFish[u] = true }
                }
                return
            }
            for v in [0] + weights {
                value[i] = v
                if byCell[i].allSatisfy(consistent) { try rec(i + 1) }
                value[i] = -1
            }
        }
        try rec(0)
        return out
    }
}
