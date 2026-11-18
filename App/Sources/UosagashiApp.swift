import SwiftUI

@main
struct UosagashiApp: App {
    /// アプリ全体で 1 つだけ（App の init は何度も呼ばれることがあるので、ここで作り直さない）
    private let model = Launch.shared

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        ZStack {
            if model.onboarded {
                HomeView()
                    .accessibilityHidden(model.inPond || model.activeSheet != nil)
            } else {
                OnboardingView()
            }
            // 池はホームの上に重ねる層
            if model.inPond, model.outing != nil {
                PondView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityHidden(model.activeSheet != nil)
                    .zIndex(1)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.86), value: model.inPond)
        .environment(model)
        // 夏の朝の釣り堀が世界。明るい昼の水辺なので、画面はライトに固定する
        .preferredColorScheme(.light)
        .sheet(item: $model.activeSheet) { sheet in
            SheetContent(sheet: sheet).environment(model).environment(\.locale, Lang.locale).preferredColorScheme(.light)
        }
        // 手応えの表（README）：押す・覗く・連鎖・釣れた・ぬし・失敗・池が空になった・浮き
        .sensoryFeedback(trigger: model.pressTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: model.openTick) { _, _ in model.hapticsOn ? .impact(weight: .light) : nil }
        .sensoryFeedback(trigger: model.chainTick) { _, _ in model.hapticsOn ? .impact(weight: .medium) : nil }
        .sensoryFeedback(trigger: model.catchTick) { _, _ in model.hapticsOn ? .impact(weight: .medium, intensity: 0.9) : nil }
        .sensoryFeedback(trigger: model.bigTick) { _, _ in model.hapticsOn ? .impact(weight: .heavy) : nil }
        .sensoryFeedback(trigger: model.failTick) { _, _ in model.hapticsOn ? .error : nil }
        .sensoryFeedback(trigger: model.clearTick) { _, _ in model.hapticsOn ? .success : nil }
        .sensoryFeedback(trigger: model.floatTick) { _, _ in model.hapticsOn ? .impact(weight: .light, intensity: 0.6) : nil }
        .task { await Launch.run(model) }
        .task { await model.purchases.load() }
        .onAppear { model.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, v in model.reduceMotion = v }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !model.still { model.now = Date() }
        }
        .environment(\.locale, Lang.locale)
    }
}

struct SheetContent: View {
    let sheet: ActiveSheet
    var body: some View {
        switch sheet {
        case .settings: SettingsView()
        case .paywall: PaywallView()
        case .codex: CodexView()
        case .records: RecordsView()
        case .share: ShareSheet()
        case .area: AreaSheet()
        case .past: PastSheet()
        }
    }
}

/// 見本の池（撮影・デモ・UI テスト）
enum Samples {
    /// 推理で分かる手を n 手まで進める（毎回同じ）。覗く手を先に、魚は釣る
    static func play(_ o: inout Outing, steps: Int, scareAt: Int? = nil) {
        var done = 0
        while done < steps && !o.isOver {
            let d = Solver.deduce(Solver.knowledge(of: o.pond))
            if d.isEmpty { break }
            if let s = d.safe.first {
                _ = o.peek(s)
            } else if let f = d.fish.first {
                if done == scareAt {
                    _ = o.peek(f)
                } else {
                    _ = o.cast(f)
                }
            }
            done += 1
        }
    }

    static func outing(_ area: Area = .village, level: Int = 11, steps: Int) -> Outing {
        var o = Outing(kind: .level(area, level), seed: Seeds.level(area, level), spec: area.spec(level), hints: 1)
        play(&o, steps: steps)
        o.seconds = 154
        return o
    }

    static func daily(_ key: String, steps: Int) -> Outing {
        var o = Outing(kind: .daily(key), seed: Seeds.daily(key), spec: Ponds.dailySpec(key), hints: 1)
        play(&o, steps: steps)
        return o
    }
}

/// 起動の仕方：ふつう・撮影（-screenshotScene <名前>）・デモ（-demo）・UI テスト（-uiTestFresh）。
/// 撮影とデモは見本のデータで動かし、保存されたデータを書き換えない
@MainActor
enum Launch {
    /// 撮る画面の名前。後ろに _ja を付けると日本語で撮る（CI のシミュレータは英語のため）
    static var scene: String? {
        var value = UserDefaults.standard.string(forKey: "screenshotScene") ?? ""
        if value.hasSuffix("_ja") { value = String(value.dropLast(3)) }
        return value.isEmpty || value == "launch" ? nil : value
    }

    static var forcesJapanese: Bool {
        UserDefaults.standard.string(forKey: "screenshotScene")?.hasSuffix("_ja") ?? false
    }

    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    static var isFreshUITest: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestFresh") }

    static let shared: AppModel = makeModel()

    /// 撮影の日（決まった日にして、連続日数などが毎回同じになるように）
    static func stageDate() -> Date {
        var c = DateComponents()
        c.year = 2026
        c.month = 11
        c.day = 18
        c.hour = 7
        c.minute = 40
        return Calendar.current.date(from: c) ?? Date()
    }

    static func makeModel() -> AppModel {
        Lang.forcedJapanese = forcesJapanese
        if isFreshUITest {
            for key in ["progress", "outing", "onboarded", "sound", "haptics", "reminder", "paywallOffered"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            let model = AppModel()
            model.soundOn = false
            return model
        }
        guard isDemo || scene != nil else { return AppModel() }
        let now = stageDate()
        let model = AppModel(persists: false, now: now)
        model.still = scene != nil
        model.onboarded = scene != "onboarding"
        if scene != "fresh" && scene != "onboarding" {
            model.progress = samples(now: now, calendar: model.calendar)
        }
        return model
    }

    /// 見本の記録：きのうまで 5 日続けて今日の池を釣り、村の釣り堀は 11 池まで
    static func samples(now: Date, calendar: Calendar) -> Progress {
        var p = Progress()
        let days: [(Int, Int, Bool, String, Double)] = [(13, 14, true, "koi", 81.5), (11, 15, false, "namazu", 62.0), (15, 15, true, "funa", 27.4), (9, 14, false, "koi", 70.2), (14, 16, true, "tanago", 8.1)]
        for (i, d) in days.enumerated() {
            let date = calendar.date(byAdding: .day, value: -(i + 1), to: now) ?? now
            p.daily[Progress.dayKey(date, calendar: calendar)] = DailyResult(caught: d.0, total: d.1, linesLost: d.2 ? 0 : 3, seconds: 240 + i * 31, cleared: d.2, bestSpecies: d.3, bestCm: d.4)
        }
        for n in 0..<11 { p.stars[Progress.key(.village, n)] = [3, 3, 2, 3, 3, 2, 3, 1, 3, 2, 3][n] }
        p.species = [
            "funa": SpeciesRecord(count: 38, bestCm: 27.4, firstDay: "2026-11-10"),
            "tanago": SpeciesRecord(count: 21, bestCm: 8.1, firstDay: "2026-11-10"),
            "moroko": SpeciesRecord(count: 15, bestCm: 11.2, firstDay: "2026-11-12"),
            "namazu": SpeciesRecord(count: 4, bestCm: 62.0, firstDay: "2026-11-13"),
            "koi": SpeciesRecord(count: 6, bestCm: 81.5, firstDay: "2026-11-12"),
            "yamame": SpeciesRecord(count: 3, bestCm: 24.6, firstDay: "2026-11-15"),
        ]
        p.totalCaught = 87
        p.pondsCleared = 16
        p.linesLostTotal = 9
        p.tutorialDone = true
        p.trialUsed = true
        return p
    }

    static func run(_ model: AppModel) async {
        if isDemo {
            await Demo.play(model)
            return
        }
        guard let scene else { return }
        try? await Task.sleep(for: .milliseconds(200))
        switch scene {
        case "pond":
            model.outing = Samples.outing(steps: 9)
            model.inPond = true
        case "rod":
            var o = Samples.outing(steps: 12)
            if let h = Solver.hint(o.pond), h.isFish {
                model.hintPos = h.0
                model.hintIsFish = true
            } else if let f = Solver.deduce(Solver.knowledge(of: o.pond)).fish.first {
                o.pond.floats.insert(f)
            }
            let fish = Solver.deduce(Solver.knowledge(of: o.pond)).fish
            for f in fish.prefix(2) { o.pond.floats.insert(f) }
            model.outing = o
            model.tool = .rod
            model.inPond = true
        case "splash":
            var o = Samples.outing(steps: 14)
            if let last = o.catches.last {
                model.splash = Splash(pos: last.pos, speciesID: last.speciesID, big: last.species?.isLunker ?? false)
                model.banner = Banner(text: trf("%@！", "%@!", last.species?.name ?? ""), sub: String(format: "%.1f cm", last.cm))
            }
            o.seconds = 98
            model.outing = o
            model.inPond = true
        case "ice":
            model.proOverride = true
            model.outing = Samples.outing(.ice, level: 9, steps: 10)
            model.inPond = true
        case "result":
            var o = Samples.outing(level: 6, steps: 400)
            o.seconds = 212
            model.newSpecies = ["moroko"]
            model.newRecords = o.catches.filter { $0.speciesID == "koi" }.prefix(1).map { $0 }
            model.outing = o
            model.inPond = true
            model.showResult = true
        case "snapped":
            var o = Samples.daily(model.todayKey, steps: 6)
            while o.lines > 0, let f = o.remainingFishPositions.first {
                _ = o.peek(f)
            }
            model.outing = o
            model.inPond = true
            model.showResult = true
        case "pause":
            model.outing = Samples.outing(steps: 9)
            model.inPond = true
            model.showPause = true
        case "resume":
            model.outing = Samples.outing(steps: 5)
        case "played":
            model.progress.daily[model.todayKey] = DailyResult(caught: 12, total: 15, linesLost: 1, seconds: 260, cleared: true, bestSpecies: "koi", bestCm: 88.3)
        case "area":
            model.browsingArea = .village
            model.activeSheet = .area
        case "codex": model.activeSheet = .codex
        case "records": model.activeSheet = .records
        case "settings": model.activeSheet = .settings
        case "paywall": model.activeSheet = .paywall
        case "share":
            let o = Samples.outing(level: 6, steps: 400)
            model.share(o)
        default: break
        }
    }
}

/// デモの再生（YouTube の録画用。人の操作なしで約 18 秒）
/// 桟橋 → 今日の池 → 覗いて連鎖で開く → 釣るに持ち替えて魚を釣る → ぬしが跳ねる
@MainActor
enum Demo {
    static func play(_ model: AppModel) async {
        func wait(_ seconds: Double) async { try? await Task.sleep(for: .milliseconds(Int(seconds * 1000))) }
        await wait(2.0)
        model.startDaily()
        await wait(1.6)
        var steps = 0
        while steps < 14, let o = model.outing, !o.isOver {
            let d = Solver.deduce(Solver.knowledge(of: o.pond))
            if let s = d.safe.first {
                if model.tool != .peek { model.tool = .peek; await wait(0.4) }
                model.tap(s)
            } else if let f = d.fish.first {
                if model.tool != .rod { model.tool = .rod; await wait(0.4) }
                model.tap(f)
            } else {
                break
            }
            steps += 1
            await wait(1.0)
        }
    }
}
