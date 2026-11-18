import Foundation
import Observation
import SwiftUI
import UserNotifications

enum ActiveSheet: String, Identifiable, Equatable {
    case settings, paywall, codex, records, share, area, past
    var id: String { rawValue }
}

/// 道具（タップで何をするか）
enum Tool: String, Codable {
    case peek, rod
}

/// 盤の上に出す一言
struct Banner: Equatable {
    var id = UUID()
    var text: String
    var sub: String = ""
}

/// 動きのための「いま起きたこと」
struct Splash: Equatable {
    var id = UUID()
    var pos: Pos
    var speciesID: String?
    var big: Bool
}

@MainActor
@Observable
final class AppModel {
    // 保存する値
    var progress: Progress { didSet { save() } }
    var outing: Outing? { didSet { saveOuting() } }
    var onboarded: Bool { didSet { store(onboarded, "onboarded") } }
    var soundOn: Bool { didSet { store(soundOn, "sound") } }
    var hapticsOn: Bool { didSet { store(hapticsOn, "haptics") } }
    var reminderOn: Bool { didSet { store(reminderOn, "reminder") } }
    /// Pro の案内は、村の 5 池目を初めて抜けた直後に 1 回だけ
    var paywallOffered: Bool { didSet { store(paywallOffered, "paywallOffered") } }

    // 画面の状態
    var inPond = false
    var tool: Tool = .peek
    /// 開いたマスの遅れ（覗いた所からの距離 × 55ms）
    var openDelays: [Pos: Double] = [:]
    var splash: Splash?
    var scaredPos: Pos?
    var missedPos: Pos?
    var hintPos: Pos?
    var hintIsFish = false
    var banner: Banner?
    var shake = 0
    var showPause = false
    var showResult = false
    /// 終わった釣りで、新しく図鑑に載った魚・大きさの記録
    var newSpecies: [String] = []
    var newRecords: [Catch] = []
    var activeSheet: ActiveSheet?
    /// 釣り場の池の一覧で開いている釣り場
    var browsingArea: Area = .village
    var now: Date
    /// 撮影・デモでは時間を止める
    var still = false
    var reduceMotion = false
    var notificationDenied = false
    /// 共有カードにする釣り
    var shareOuting: Outing?

    // 手応え（値が変わると振動）
    var pressTick = 0
    var openTick = 0
    var chainTick = 0
    var catchTick = 0
    var bigTick = 0
    var failTick = 0
    var clearTick = 0
    var floatTick = 0

    let purchases: PurchaseStore
    var proOverride = false
    var isPro: Bool { proOverride || purchases.entitlements.isPro }

    private let persists: Bool
    let calendar = Calendar.current

    static let bundleID = Bundle.main.bundleIdentifier ?? "com.enludus.daily.013"
    static var proID: String { ProductID.pro(bundleID: bundleID) }

    init(persists: Bool = true, now: Date = Date()) {
        self.persists = persists
        self.now = now
        let d = UserDefaults.standard
        if persists, let data = d.data(forKey: "progress"), let p = try? JSONDecoder().decode(Progress.self, from: data) {
            progress = p
        } else {
            progress = Progress()
        }
        if persists, let data = d.data(forKey: "outing"), let o = try? JSONDecoder().decode(Outing.self, from: data), !o.isOver {
            outing = o
        } else {
            outing = nil
        }
        onboarded = persists ? d.bool(forKey: "onboarded") : true
        soundOn = persists ? (d.object(forKey: "sound") as? Bool ?? true) : true
        hapticsOn = persists ? (d.object(forKey: "haptics") as? Bool ?? true) : true
        reminderOn = persists ? d.bool(forKey: "reminder") : false
        paywallOffered = persists ? d.bool(forKey: "paywallOffered") : true
        purchases = PurchaseStore(productIDs: [Self.proID], proProductIDs: [Self.proID])
    }

    private func save() {
        guard persists, let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: "progress")
    }

    private func saveOuting() {
        guard persists else { return }
        if let outing, !outing.isOver, let data = try? JSONEncoder().encode(outing) {
            UserDefaults.standard.set(data, forKey: "outing")
        } else {
            UserDefaults.standard.removeObject(forKey: "outing")
        }
    }

    private func store(_ value: Bool, _ key: String) {
        guard persists else { return }
        UserDefaults.standard.set(value, forKey: key)
    }

    // MARK: - 読む値

    var todayKey: String { Progress.dayKey(now, calendar: calendar) }
    var todayResult: DailyResult? { progress.daily[todayKey] }
    var streak: Int { progress.streak(today: now, calendar: calendar) }
    var hintsPerPond: Int { isPro ? 3 : 1 }

    func canPlay(_ area: Area, _ level: Int) -> Bool {
        if area.isPro && !isPro {
            return area == .stream && level == 0 && !progress.trialUsed
        }
        return level <= progress.unlockedLevel(area)
    }

    /// 最近 7 日の今日の池（古い順）
    func lastWeek() -> [(String, DailyResult?)] {
        (0..<7).reversed().compactMap { back in
            guard let d = calendar.date(byAdding: .day, value: -back, to: now) else { return nil }
            let k = Progress.dayKey(d, calendar: calendar)
            return (k, progress.daily[k])
        }
    }

    /// 過去の今日の池（Pro：14 日ぶん）
    func pastDays() -> [String] {
        (1...14).compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: now).map { Progress.dayKey($0, calendar: calendar) }
        }
    }

    // MARK: - 始める

    func startDaily() {
        guard todayResult == nil else { return }
        if let o = outing, o.kind == .daily(todayKey), !o.isOver {
            resume()
            return
        }
        begin(Outing(kind: .daily(todayKey), seed: Seeds.daily(todayKey), spec: Ponds.dailySpec(todayKey), hints: hintsPerPond))
    }

    func startPast(_ key: String) {
        guard isPro else {
            activeSheet = .paywall
            return
        }
        // 過去の池は記録に残さない（気ままにと同じ扱い）
        begin(Outing(kind: .free(1), seed: Seeds.daily(key), spec: Ponds.dailySpec(key), hints: hintsPerPond))
        banner = Banner(text: tr("過去の池", "A past pond"), sub: key)
    }

    func startLevel(_ area: Area, _ level: Int) {
        guard canPlay(area, level) else {
            if area.isPro && !isPro { activeSheet = .paywall }
            return
        }
        if area.isPro && !isPro { progress.trialUsed = true }
        begin(Outing(kind: .level(area, level), seed: Seeds.level(area, level), spec: area.spec(level), hints: hintsPerPond))
        banner = Banner(text: area.name, sub: trf("%d 番目の池", "Pond %d", level + 1))
    }

    func startFree(_ size: Int) {
        begin(Outing(kind: .free(size), seed: UInt64.random(in: 1...(1 << 52)), spec: Ponds.freeSpec(size), hints: hintsPerPond))
    }

    func startTutorial() {
        begin(Outing(kind: .tutorial, seed: Ponds.tutorialSeed, spec: Ponds.tutorialSpec, hints: 3))
        banner = Banner(text: tr("はじめての池", "Your first pond"), sub: tr("まずは覗いてみよう", "Start by peeking"))
    }

    func begin(_ o: Outing) {
        outing = o
        tool = .peek
        clearMarks()
        showResult = false
        showPause = false
        activeSheet = nil
        inPond = true
        if soundOn { SoundBox.shared.play(.start) }
    }

    func resume() {
        guard outing != nil else { return }
        clearMarks()
        inPond = true
    }

    func leavePond() {
        inPond = false
        showPause = false
        showResult = false
        if let o = outing, o.isOver { outing = nil }
    }

    private func clearMarks() {
        openDelays = [:]
        splash = nil
        scaredPos = nil
        missedPos = nil
        hintPos = nil
        banner = nil
    }

    // MARK: - 操作

    func tap(_ p: Pos) {
        guard var o = outing, !o.isOver else { return }
        pressTick += 1
        hintPos = nil
        let event = tool == .peek ? o.peek(p) : o.cast(p)
        outing = o
        handle(event)
    }

    func longPress(_ p: Pos) {
        guard var o = outing, !o.isOver else { return }
        if o.toggleFloat(p) {
            outing = o
            floatTick += 1
            if soundOn { SoundBox.shared.play(.float) }
        }
    }

    func useHint() {
        guard var o = outing else { return }
        if let h = o.useHint() {
            outing = o
            hintPos = h.0
            hintIsFish = h.isFish
            tool = h.isFish ? .rod : .peek
            pressTick += 1
            if soundOn { SoundBox.shared.play(.hint) }
        } else if o.hintsLeft == 0 {
            banner = Banner(text: tr("ヒントは使い切った", "No hints left"), sub: isPro ? "" : tr("Pro なら 1 池 3 回", "Pro gets 3 per pond"))
        }
    }

    private func handle(_ event: Outing.Event) {
        switch event {
        case .none:
            return
        case .opened(let cells):
            openDelays = cells.mapValues { reduceMotion ? 0 : Double($0) * 0.055 }
            if cells.count >= 6 {
                chainTick += 1
                if soundOn { SoundBox.shared.play(.chain) }
            } else {
                openTick += 1
                if soundOn { SoundBox.shared.play(.peek) }
            }
        case .scared(let p):
            scaredPos = p
            failTick += 1
            shake += 1
            if soundOn { SoundBox.shared.play(.snap) }
            banner = Banner(text: tr("魚が逃げた！", "It got away!"), sub: tr("糸が 1 本切れた", "One line snapped"))
        case .caught(let c):
            let big = c.species?.isLunker ?? false
            splash = Splash(pos: c.pos, speciesID: c.speciesID, big: big)
            if big {
                bigTick += 1
                if soundOn { SoundBox.shared.play(.lunker) }
            } else {
                catchTick += 1
                if soundOn { SoundBox.shared.play(.catchFish) }
            }
            if big, let sp = c.species {
                banner = Banner(text: trf("ぬしの %@！", "A lunker %@!", sp.name), sub: String(format: "%.1f cm", c.cm))
            }
        case .missed(let p, let cells):
            missedPos = p
            openDelays = cells.mapValues { reduceMotion ? 0 : Double($0) * 0.055 }
            failTick += 1
            shake += 1
            if soundOn { SoundBox.shared.play(.snap) }
            banner = Banner(text: tr("空振り…", "Nothing there…"), sub: tr("糸が 1 本切れた", "One line snapped"))
        }
        if let o = outing, o.isOver { finish(o) }
    }

    private func finish(_ o: Outing) {
        newSpecies = progress.newSpecies(in: o)
        newRecords = progress.newRecords(in: o)
        let firstVillage5 = o.kind == .level(.village, 4) && progress.starsFor(.village, 4) == 0 && o.status == .cleared
        progress.record(o, dayKey: todayKey)
        if o.status == .cleared {
            clearTick += 1
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(still ? 0 : 900))
            if self.soundOn { SoundBox.shared.play(o.status == .cleared ? .fanfare : .sad) }
            self.showResult = true
            // 価値を感じた直後（村の 5 池目を初めて抜けた）に 1 回だけ Pro の案内
            if firstVillage5 && !self.paywallOffered && !self.isPro {
                self.paywallOffered = true
                try? await Task.sleep(for: .milliseconds(1600))
                if self.showResult { self.activeSheet = .paywall }
            }
        }
    }

    /// 次の池へ（釣り場の池のときだけ）
    func nextLevel() {
        guard let o = outing, case .level(let a, let n) = o.kind else { return }
        if n + 1 < Area.levelsPerArea && canPlay(a, n + 1) {
            startLevel(a, n + 1)
        } else {
            leavePond()
            if a.isPro && !isPro { activeSheet = .paywall }
        }
    }

    func retry() {
        guard let o = outing else { return }
        switch o.kind {
        case .level(let a, let n): startLevel(a, n)
        case .free(let s): startFree(s)
        case .tutorial: startTutorial()
        case .daily: leavePond()
        }
    }

    func share(_ o: Outing?) {
        shareOuting = o
        activeSheet = .share
    }

    // MARK: - 通知（今日の池の知らせ。毎朝 7:30）

    func setReminder(_ on: Bool) async {
        let center = UNUserNotificationCenter.current()
        if !on {
            center.removeAllPendingNotificationRequests()
            reminderOn = false
            return
        }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else {
            notificationDenied = true
            reminderOn = false
            return
        }
        notificationDenied = false
        let content = UNMutableNotificationContent()
        content.title = tr("今日の池が開いた", "Today's pond is open")
        content.body = tr("水の下に魚がいる。数を読んで釣ろう。", "Fish are hiding under the water. Read the ripples and cast.")
        var when = DateComponents()
        when.hour = 7
        when.minute = 30
        let request = UNNotificationRequest(identifier: "daily-pond", content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true))
        try? await center.add(request)
        reminderOn = true
    }
}
