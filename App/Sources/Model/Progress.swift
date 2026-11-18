import Foundation

/// 今日の池の結果
struct DailyResult: Codable, Equatable, Sendable {
    var caught: Int
    var total: Int
    var linesLost: Int
    var seconds: Int
    var cleared: Bool
    /// その日いちばんの 1 匹
    var bestSpecies: String?
    var bestCm: Double?
}

/// 図鑑の 1 種の記録
struct SpeciesRecord: Codable, Equatable, Sendable {
    var count: Int = 0
    var bestCm: Double = 0
    var firstDay: String?
}

/// 保存する記録（端末の中だけ）
struct Progress: Codable, Equatable, Sendable {
    /// 釣り場の池ごとの星（"village-3" → 0〜3）
    var stars: [String: Int] = [:]
    var daily: [String: DailyResult] = [:]
    var species: [String: SpeciesRecord] = [:]
    var totalCaught = 0
    var pondsCleared = 0
    var linesLostTotal = 0
    var tutorialDone = false
    /// 渓流の 1 池目のお試し（Pro でない人が 1 回だけ）
    var trialUsed = false

    static func key(_ area: Area, _ level: Int) -> String { "\(area.rawValue)-\(level)" }

    func starsFor(_ area: Area, _ level: Int) -> Int { stars[Self.key(area, level)] ?? 0 }

    /// 釣り場で、次に遊べる池（抜けた池の次まで開く）
    func unlockedLevel(_ area: Area) -> Int {
        var n = 0
        while n < Area.levelsPerArea && starsFor(area, n) > 0 { n += 1 }
        return min(n, Area.levelsPerArea - 1)
    }

    func clearedCount(_ area: Area) -> Int {
        (0..<Area.levelsPerArea).filter { starsFor(area, $0) > 0 }.count
    }

    func starTotal(_ area: Area) -> Int {
        (0..<Area.levelsPerArea).reduce(0) { $0 + starsFor(area, $1) }
    }

    var discovered: Int { species.values.filter { $0.count > 0 }.count }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// 続けた日数（今日か昨日まで続いている今日の池）
    func streak(today: Date, calendar: Calendar) -> Int {
        var day = today
        if daily[Self.dayKey(day, calendar: calendar)] == nil {
            guard let y = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        var n = 0
        while daily[Self.dayKey(day, calendar: calendar)] != nil {
            n += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    /// 終わった釣りを記録に入れる
    mutating func record(_ o: Outing, dayKey: String) {
        for c in o.catches {
            var r = species[c.speciesID] ?? SpeciesRecord()
            r.count += 1
            r.bestCm = max(r.bestCm, c.cm)
            if r.firstDay == nil { r.firstDay = dayKey }
            species[c.speciesID] = r
        }
        totalCaught += o.catches.count
        linesLostTotal += o.linesLost
        if o.status == .cleared { pondsCleared += 1 }
        switch o.kind {
        case .level(let a, let n):
            let k = Self.key(a, n)
            stars[k] = max(stars[k] ?? 0, o.stars)
        case .daily(let key):
            if daily[key] == nil {
                let best = o.bestCatch
                daily[key] = DailyResult(caught: o.catches.count, total: o.totalFish, linesLost: o.linesLost, seconds: o.seconds,
                                         cleared: o.status == .cleared, bestSpecies: best?.speciesID, bestCm: best?.cm)
            }
        case .tutorial:
            tutorialDone = true
        case .free:
            break
        }
    }

    /// 1 回の釣りで新しく図鑑に載った魚
    func newSpecies(in o: Outing) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for c in o.catches where (species[c.speciesID]?.count ?? 0) == 0 && !seen.contains(c.speciesID) {
            seen.insert(c.speciesID)
            out.append(c.speciesID)
        }
        return out
    }

    /// 1 回の釣りで大きさの記録を更新した魚
    func newRecords(in o: Outing) -> [Catch] {
        var best: [String: Catch] = [:]
        for c in o.catches where c.cm > (species[c.speciesID]?.bestCm ?? 0) && (species[c.speciesID]?.count ?? 0) > 0 {
            if c.cm > (best[c.speciesID]?.cm ?? 0) { best[c.speciesID] = c }
        }
        return best.values.sorted { $0.cm > $1.cm }
    }
}
