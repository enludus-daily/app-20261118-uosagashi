import Foundation
import Testing
@testable import Uosagashi

struct PondTests {
    @Test func sameSeedMakesTheSamePond() {
        let spec = Area.village.spec(12)
        let a = Pond.generate(spec, seed: 42)
        let b = Pond.generate(spec, seed: 42)
        #expect(a == b)
        #expect(a != Pond.generate(spec, seed: 43))
    }

    @Test func pierStartsOpenWithNoFishAround() {
        let pond = Pond.generate(Area.village.spec(5), seed: 7)
        #expect(pond[pond.pier] == .open)
        #expect(pond.number(at: pond.pier) == 0)
        for n in pond.neighbors(pond.pier) {
            #expect(!pond.hasFish(n))
            #expect(pond[n] == .open)
        }
    }

    @Test func lunkersCountAsTwo() {
        var pond = Pond(rows: 3, cols: 3)
        pond.weight[pond.index(Pos(0, 0))] = 2
        pond.weight[pond.index(Pos(0, 1))] = 1
        #expect(pond.number(at: Pos(1, 1)) == 3)
        #expect(pond.number(at: Pos(2, 2)) == 0)
    }

    @Test func zeroOpensItsNeighbors() {
        var pond = Pond(rows: 4, cols: 4)
        pond.weight[pond.index(Pos(0, 0))] = 1
        let opened = pond.open(from: Pos(3, 3))
        #expect(opened.count == 15)
        #expect(pond[Pos(0, 0)] == .hidden)
        #expect(opened.first?.1 == 0)
        #expect((opened.map(\.1).max() ?? 0) >= 2)
    }

    @Test func iceHidesTheNumberAndDoesNotSpread() {
        var pond = Pond(rows: 3, cols: 3)
        pond.terrain[pond.index(Pos(1, 1))] = .ice
        let opened = pond.open(from: Pos(1, 1))
        #expect(opened.count == 1)
        #expect(!pond.showsNumber(Pos(1, 1)))
    }

    @Test(arguments: Area.allCases)
    func everyPondOfEveryAreaIsSolvableByLogicAlone(area: Area) {
        for level in 0..<Area.levelsPerArea {
            let spec = area.spec(level)
            let pond = Pond.generate(spec, seed: Seeds.level(area, level))
            #expect(Solver.solvesFromPier(pond), "\(area) \(level)")
            #expect(pond.totalFish >= spec.fishCount - 2, "\(area) \(level): \(pond.totalFish) / \(spec.fishCount)")
            let schools = (0..<pond.weight.count).filter { pond.schooled[$0] }.count
            #expect(schools % 3 == 0)
        }
    }

    @Test func dailyPondsAreSolvableForAMonth() {
        for d in 1...30 {
            let key = String(format: "2026-12-%02d", d)
            let pond = Pond.generate(Ponds.dailySpec(key), seed: Seeds.daily(key))
            #expect(Solver.solvesFromPier(pond), "\(key)")
        }
    }
}

struct SolverTests {
    /// 推理で出たマスは、必ず答えと合う（魚がいないと言ったマスに魚はいない）
    @Test func deductionsAreNeverWrong() {
        for seed in 1...40 {
            var o = Outing(kind: .free(1), seed: UInt64(seed), spec: Ponds.freeSpec(1), hints: 1)
            for _ in 0..<200 where !o.isOver {
                let d = Solver.deduce(Solver.knowledge(of: o.pond))
                if d.isEmpty { break }
                for s in d.safe { #expect(!o.pond.hasFish(s)) }
                for f in d.fish { #expect(o.pond.hasFish(f)) }
                if let s = d.safe.first {
                    _ = o.peek(s)
                } else if let f = d.fish.first {
                    _ = o.cast(f)
                }
            }
            #expect(o.status == .cleared)
            #expect(o.lines == Outing.maxLines)
        }
    }

    @Test func hintPointsAtACorrectTile() {
        var o = Outing(kind: .free(0), seed: 99, spec: Ponds.freeSpec(0), hints: 1)
        let h = o.useHint()
        #expect(h != nil)
        if let h { #expect(o.pond.hasFish(h.0) == h.isFish) }
        #expect(o.hintsLeft == 0)
        let again = o.useHint()
        #expect(again == nil)
    }

    @Test func remainingCountSolvesTheLastCorner() {
        // 右上の 1 マスだけが分からず、魚が 1 匹残っている：数がなくても残りの数で決まる
        var pond = Pond(rows: 3, cols: 3)
        pond.weight[pond.index(Pos(0, 2))] = 1
        for p in pond.allPositions where p != Pos(0, 2) { pond[p] = .open }
        let d = Solver.deduce(Solver.knowledge(of: pond))
        #expect(d.fish == [Pos(0, 2)])
    }
}

struct OutingTests {
    private func sample() -> Outing {
        Outing(kind: .level(.village, 3), seed: 5, spec: Area.village.spec(3), hints: 1)
    }

    @Test func peekingAFishScaresItAndSnapsALine() {
        var o = sample()
        guard let f = o.remainingFishPositions.first else {
            Issue.record("no fish")
            return
        }
        let e = o.peek(f)
        #expect(e == .scared(f))
        #expect(o.pond[f] == .escaped)
        #expect(o.lines == 2)
    }

    @Test func castingOnAFishCatchesIt() {
        var o = sample()
        guard let f = o.remainingFishPositions.first else {
            Issue.record("no fish")
            return
        }
        guard case .caught(let c) = o.cast(f) else {
            Issue.record("not caught")
            return
        }
        #expect(o.lines == 3)
        #expect(c.species?.area == .village)
        let sp = c.species
        #expect(c.cm >= Double(sp?.minCm ?? 0) && c.cm <= Double(sp?.maxCm ?? 0))
    }

    @Test func castingOnEmptyWaterSnapsALineButOpensTheTile() {
        var o = sample()
        guard let empty = o.pond.allPositions.first(where: { o.pond[$0] == .hidden && !o.pond.hasFish($0) && o.pond.terrainAt($0) != .weed }) else { return }
        guard case .missed(let p, let opened) = o.cast(empty) else {
            Issue.record("not missed")
            return
        }
        #expect(p == empty)
        #expect(opened[empty] == 0)
        #expect(o.lines == 2)
        #expect(o.pond[empty] == .open)
    }

    @Test func threeMistakesEndTheOuting() {
        var o = sample()
        for f in o.remainingFishPositions.prefix(3) { _ = o.peek(f) }
        #expect(o.status == .snapped)
        #expect(o.stars == 0)
        let after = o.peek(o.pond.pier)
        #expect(after == .none)
    }

    @Test func floatsProtectFromPeeking() {
        var o = sample()
        guard let f = o.remainingFishPositions.first else { return }
        let placed = o.toggleFloat(f)
        #expect(placed)
        let peeked = o.peek(f)
        #expect(peeked == .none)
        #expect(o.lines == 3)
        let removed = o.toggleFloat(f)
        #expect(removed)
        #expect(!o.pond.floats.contains(f))
    }

    @Test func starsFollowLinesLost() {
        var o = sample()
        guard let first = o.remainingFishPositions.first else { return }
        _ = o.peek(first)
        for f in o.remainingFishPositions { _ = o.cast(f) }
        #expect(o.status == .cleared)
        #expect(o.stars == 2)
    }

    @Test func aSchoolIsOneSpecies() {
        for seed in 1...20 {
            var o = Outing(kind: .level(.village, 13), seed: UInt64(seed), spec: Area.village.spec(13), hints: 1)
            for f in o.remainingFishPositions { _ = o.cast(f) }
            let schooled = o.catches.filter { o.pond.schooled[o.pond.index($0.pos)] }
            for c in schooled { #expect(c.species?.school == true) }
            // 横に並んだ 3 匹ごとに同じ種
            let byRow = Dictionary(grouping: schooled, by: { $0.pos.r })
            for (_, row) in byRow {
                let sorted = row.sorted { $0.pos.c < $1.pos.c }
                var i = 0
                while i + 2 < sorted.count {
                    if sorted[i + 2].pos.c - sorted[i].pos.c == 2 {
                        #expect(Set(sorted[i...(i + 2)].map(\.speciesID)).count == 1)
                    }
                    i += 3
                }
            }
        }
    }
}

struct ProgressTests {
    let calendar = Calendar(identifier: .gregorian)

    private func date(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: 9)) ?? Date()
    }

    @Test func streakCountsBackFromTodayOrYesterday() {
        var p = Progress()
        for d in [14, 15, 16, 17] {
            p.daily[Progress.dayKey(date(d), calendar: calendar)] = DailyResult(caught: 1, total: 2, linesLost: 0, seconds: 1, cleared: false)
        }
        #expect(p.streak(today: date(18), calendar: calendar) == 4)
        #expect(p.streak(today: date(17), calendar: calendar) == 4)
        #expect(p.streak(today: date(20), calendar: calendar) == 0)
    }

    @Test func recordingKeepsTheBestSizeAndStars() {
        var p = Progress()
        var o = Outing(kind: .level(.village, 0), seed: 3, spec: Area.village.spec(0), hints: 1)
        for f in o.remainingFishPositions { _ = o.cast(f) }
        let fresh = p.newSpecies(in: o)
        #expect(!fresh.isEmpty)
        p.record(o, dayKey: "2026-11-18")
        #expect(p.starsFor(.village, 0) == 3)
        #expect(p.unlockedLevel(.village) == 1)
        #expect(p.totalCaught == o.catches.count)
        for c in o.catches { #expect((p.species[c.speciesID]?.bestCm ?? 0) >= c.cm) }
        #expect(p.newSpecies(in: o).isEmpty)
    }

    @Test func theDailyPondIsRecordedOnce() {
        var p = Progress()
        var o = Outing(kind: .daily("2026-11-18"), seed: Seeds.daily("2026-11-18"), spec: Ponds.dailySpec("2026-11-18"), hints: 1)
        for f in o.remainingFishPositions.prefix(3) { _ = o.peek(f) }
        p.record(o, dayKey: "2026-11-18")
        let first = p.daily["2026-11-18"]
        #expect(first?.cleared == false)
        p.record(o, dayKey: "2026-11-18")
        #expect(p.daily["2026-11-18"] == first)
    }

    @Test func dailySeedDependsOnTheDate() {
        #expect(Seeds.daily("2026-11-18") == Seeds.daily("2026-11-18"))
        #expect(Seeds.daily("2026-11-18") != Seeds.daily("2026-11-19"))
    }

    @Test func everyAreaHasFiveSpeciesWithEveryRole() {
        for a in Area.allCases {
            let s = a.species
            #expect(s.count == 5)
            #expect(s.contains { $0.weight == 2 })
            #expect(s.contains { $0.school })
            #expect(s.contains { $0.weight == 1 && !$0.school })
        }
        #expect(Set(Species.all.map(\.id)).count == Species.all.count)
    }
}
