import SwiftUI
import UIKit

// MARK: - 釣り場の池の一覧

struct AreaSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let area = model.browsingArea
        let locked = area.isPro && !model.isPro
        SheetFrame(title: area.name, area: area, closeID: "main.closeArea") {
            Text(area.rule).font(Theme.label(14)).foregroundStyle(Theme.cream).frame(maxWidth: .infinity, alignment: .leading)
            if locked {
                PlankCard(seed: 31) {
                    Text(tr("この釣り場は Pro で開く", "This spot opens with Pro")).font(Theme.label(16, weight: .heavy)).foregroundStyle(Theme.ink)
                    Text(area == .stream && !model.progress.trialUsed ? tr("1 番目の池だけ、1 回ためしに釣れる。", "You can try Pond 1 once for free.")
                                                                      : tr("20 の池と、ここにしかいない魚 5 種。", "20 ponds and 5 fish found nowhere else."))
                        .font(Theme.label(13)).foregroundStyle(Theme.inkSoft)
                    Button(tr("Pro を見る", "See Pro")) { model.activeSheet = .paywall }
                        .buttonStyle(PlankButtonStyle(prominent: true))
                        .accessibilityIdentifier("area.pro")
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                ForEach(0..<Area.levelsPerArea, id: \.self) { n in
                    let open = model.canPlay(area, n)
                    let stars = model.progress.starsFor(area, n)
                    Button {
                        dismiss()
                        model.startLevel(area, n)
                    } label: {
                        VStack(spacing: 3) {
                            ZStack {
                                Circle().fill(open ? Theme.leaf : Theme.leafDeep.opacity(0.5))
                                    .overlay(Circle().stroke(Theme.leafDeep, lineWidth: 1.5))
                                if open {
                                    Text("\(n + 1)").font(Theme.sign(22)).foregroundStyle(Theme.cream).monospacedDigit()
                                } else {
                                    Image(systemName: "lock.fill").foregroundStyle(Theme.cream.opacity(0.7))
                                }
                            }
                            .frame(width: 58, height: 58)
                            StarsView(stars: stars, size: 10)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!open)
                    .accessibilityLabel(trf("%d 番目の池", "Pond %d", n + 1))
                    .accessibilityIdentifier("level.\(n)")
                }
            }
            .padding(.top, 6)
        }
    }
}

// MARK: - 図鑑

struct CodexView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        SheetFrame(title: tr("魚図鑑", "Fishbook"), closeID: "main.closeCodex") {
            Text(trf("%d / %d 種", "%d of %d species", model.progress.discovered, Species.all.count))
                .font(Theme.label(15, weight: .bold)).foregroundStyle(Theme.cream).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Area.allCases) { area in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(area.name).signStyle(19)
                        if area.isPro && !model.isPro {
                            Text("Pro").font(Theme.label(11, weight: .heavy)).foregroundStyle(Theme.cream)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Theme.bobber))
                        }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        ForEach(area.species) { sp in SpeciesCard(species: sp) }
                    }
                }
            }
        }
    }
}

struct SpeciesCard: View {
    @Environment(AppModel.self) private var model
    let species: Species

    var body: some View {
        let rec = model.progress.species[species.id]
        let found = (rec?.count ?? 0) > 0
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Theme.water(species.area).clear.opacity(0.7))
                FishView(species: species, width: 92, silhouette: !found)
            }
            .frame(height: 64)
            Text(found ? species.name : "？？？").font(Theme.label(15, weight: .heavy)).foregroundStyle(Theme.ink)
            Text(species.isLunker ? tr("ぬし・2 匹ぶん", "Lunker · counts 2") : (species.school ? tr("群れ・横に 3 匹", "School · 3 in a row") : tr("小魚", "Minnow")))
                .font(Theme.label(11)).foregroundStyle(Theme.bobberDeep)
            if found, let rec {
                Text(trf("%d 匹・最大 %.1f cm", "%d caught · best %.1f cm", rec.count, rec.bestCm)).font(Theme.label(12)).monospacedDigit().foregroundStyle(Theme.ink)
                Text(species.note).font(Theme.body(11)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(trf("%d〜%d cm。まだ釣っていない", "%d–%d cm. Not caught yet", species.minCm, species.maxCm)).font(Theme.label(12)).foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(PlankBackground(seed: UInt64(species.id.count)))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 記録

struct RecordsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let p = model.progress
        SheetFrame(title: tr("釣りの記録", "Records"), closeID: "main.closeRecords") {
            PlankCard(seed: 41) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(model.streak)").font(Theme.sign(56)).monospacedDigit().foregroundStyle(Theme.ink)
                    Text(tr("日つづけて", "day streak")).font(Theme.label(16, weight: .bold)).foregroundStyle(Theme.inkSoft)
                }
                Text(model.streak == 0 && !p.daily.isEmpty ? tr("おかえり。今日の池から、また始めよう。", "Welcome back. Today's pond is waiting.")
                                                            : trf("今日の池を釣った日は、ぜんぶで %d 日", "%d daily ponds fished in total", p.daily.count))
                    .font(Theme.label(13)).foregroundStyle(Theme.inkSoft)
                WeekStrip()
            }
            HStack(spacing: 10) {
                bigStat("\(p.totalCaught)", tr("釣った魚", "Fish caught"))
                bigStat("\(p.pondsCleared)", tr("空にした池", "Ponds cleared"))
                bigStat("\(p.discovered)", tr("見つけた種", "Species"))
            }
            PlankCard(seed: 42) {
                Text(tr("大きさの記録", "Size records")).font(Theme.label(16, weight: .heavy)).foregroundStyle(Theme.ink)
                let top = Species.all.compactMap { sp in p.species[sp.id].map { (sp, $0) } }.sorted { $0.1.bestCm > $1.1.bestCm }.prefix(6)
                if top.isEmpty {
                    Text(tr("まだ記録がない。今日の池で 1 匹目を。", "No records yet. Catch your first in today's pond."))
                        .font(Theme.body(13)).foregroundStyle(Theme.inkSoft)
                }
                ForEach(Array(top), id: \.0.id) { sp, rec in
                    HStack(spacing: 10) {
                        FishView(species: sp, width: 44)
                        Text(sp.name).font(Theme.label(14, weight: .bold)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(String(format: "%.1f cm", rec.bestCm)).font(Theme.label(15, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
                    }
                }
            }
            PlankCard(seed: 43) {
                Text(tr("釣り場", "Fishing spots")).font(Theme.label(16, weight: .heavy)).foregroundStyle(Theme.ink)
                ForEach(Area.allCases) { a in
                    HStack {
                        Text(a.name).font(Theme.label(14)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(p.clearedCount(a))/\(Area.levelsPerArea)").font(Theme.label(14, weight: .bold)).monospacedDigit().foregroundStyle(Theme.ink)
                        Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(Theme.sun)
                        Text("\(p.starTotal(a))").font(Theme.label(13)).monospacedDigit().foregroundStyle(Theme.inkSoft)
                    }
                }
            }
        }
    }

    private func bigStat(_ v: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(Theme.sign(28)).monospacedDigit().foregroundStyle(Theme.ink)
            Text(label).font(Theme.label(11)).foregroundStyle(Theme.inkSoft).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(PlankBackground(seed: UInt64(label.count)))
    }
}

// MARK: - 設定

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var model = model
        SheetFrame(title: tr("設定", "Settings"), closeID: "main.closeSettings") {
            PlankCard(seed: 51) {
                Toggle(tr("効果音", "Sound effects"), isOn: $model.soundOn).font(Theme.label(15)).foregroundStyle(Theme.ink).tint(Theme.bobber)
                Toggle(tr("振動", "Haptics"), isOn: $model.hapticsOn).font(Theme.label(15)).foregroundStyle(Theme.ink).tint(Theme.bobber)
                Toggle(tr("今日の池の知らせ（朝 7:30）", "Daily pond reminder (7:30 AM)"), isOn: Binding(
                    get: { model.reminderOn },
                    set: { on in Task { await model.setReminder(on) } }))
                    .font(Theme.label(15)).foregroundStyle(Theme.ink).tint(Theme.bobber)
                if model.notificationDenied {
                    Text(tr("通知が許可されていません。設定アプリで「うおさがし」の通知をオンにしてください。", "Notifications are off for this app. Turn them on in the Settings app."))
                        .font(Theme.label(12)).foregroundStyle(Theme.bobberDeep)
                    Button(tr("設定アプリを開く", "Open Settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(PlankButtonStyle(compact: true))
                }
            }
            PlankCard(seed: 52) {
                Text(tr("遊び方", "How to play")).font(Theme.label(16, weight: .heavy)).foregroundStyle(Theme.ink)
                Text(tr("・覗く：まわり 8 マスの魚の数が出る（ぬしは 2 匹ぶん）\n・釣る：魚がいると読んだマスに竿を垂らす\n・外す・魚を驚かせると糸が 1 本切れる（3 本）\n・長押し：浮き（ここは魚、の印）",
                        "• Peek: shows how many fish are in the 8 tiles around (lunkers count 2)\n• Cast: drop your line where you know a fish is\n• A miss or a spooked fish snaps one line (you have 3)\n• Hold: set a float to mark a fish"))
                    .font(Theme.body(13)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                Button(tr("案内をもう一度見る", "Show the intro again")) {
                    model.activeSheet = nil
                    model.onboarded = false
                }
                .buttonStyle(PlankButtonStyle())
                .accessibilityIdentifier("settings.onboarding")
            }
            PlankCard(seed: 53) {
                Text("Pro").font(Theme.label(16, weight: .heavy)).foregroundStyle(Theme.ink)
                Text(model.isPro ? tr("Pro を使っています。ありがとう。", "You have Pro. Thank you.") : tr("釣り場 3 つ・魚 15 種・過去の今日の池・ヒント 3 回", "3 more spots, 15 more fish, past ponds, 3 hints"))
                    .font(Theme.label(13)).foregroundStyle(Theme.inkSoft)
                if !model.isPro {
                    Button(tr("Pro を見る", "See Pro")) { model.activeSheet = .paywall }
                        .buttonStyle(PlankButtonStyle(prominent: true))
                        .accessibilityIdentifier("settings.pro")
                }
                Button(tr("購入を復元", "Restore purchases")) { Task { await model.purchases.restore() } }
                    .buttonStyle(PlankButtonStyle())
            }
            PlankCard(seed: 54) {
                Text(tr("プライバシー", "Privacy")).font(Theme.label(16, weight: .heavy)).foregroundStyle(Theme.ink)
                Text(tr("記録はこの iPhone の中だけに残ります。外へ送らず、広告も解析もありません。", "Your records stay on this iPhone. Nothing is sent anywhere — no ads, no analytics."))
                    .font(Theme.body(13)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                Text("v" + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"))
                    .font(Theme.label(11)).foregroundStyle(Theme.inkSoft)
            }
        }
    }
}

// MARK: - Pro

struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @State private var working = false
    @State private var message: String?

    var body: some View {
        SheetFrame(title: tr("うおさがし Pro", "Ripple Pond Pro"), area: .stream, closeID: "main.closePaywall") {
            Text(tr("買い切り。いちど買えば、ずっと。", "One-time purchase. Yours for good."))
                .font(Theme.label(14)).foregroundStyle(Theme.cream)
            feature(icon: AnyView(HStack(spacing: -10) {
                ForEach([Area.stream, .shore, .ice], id: \.self) { a in
                    RoundedRectangle(cornerRadius: 8).fill(LinearGradient(colors: [Theme.water(a).surface, Theme.water(a).deep], startPoint: .top, endPoint: .bottom))
                        .frame(width: 40, height: 50).overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.6), lineWidth: 1.5))
                }
            }), title: tr("釣り場 3 つ・60 の池", "3 new spots · 60 ponds"),
                    detail: tr("岩の多い渓流、ぬしだらけの磯、数が見えない氷の湖。決まりが変わり、推理が深くなる。", "A rocky stream, lunker-filled tide pools, and a frozen lake where ice hides the numbers."))
            feature(icon: AnyView(HStack(spacing: -14) {
                ForEach(["itou", "madai", "nijimasu"], id: \.self) { id in
                    if let sp = Species.find(id) { FishView(species: sp, width: 52) }
                }
            }), title: tr("魚 15 種で図鑑が埋まる", "15 more fish for your Fishbook"),
                    detail: tr("幻のイトウ、めでたいマダイ、虹色のニジマス…。大きさの記録も残る。", "The legendary taimen, red sea bream, rainbow trout… with size records."))
            feature(icon: AnyView(Image(systemName: "calendar").font(.system(size: 34, weight: .bold)).foregroundStyle(Theme.ink)),
                    title: tr("過去の今日の池・ヒント 3 回", "Past daily ponds · 3 hints"),
                    detail: tr("見逃した日の池を 14 日前まで遊べる。ヒントは 1 池 3 回（無料は 1 回）。", "Play any daily pond from the last 14 days. 3 hints per pond (free: 1)."))
            priceArea
            Text(tr("村の釣り堀 20 池・今日の池・気ままに・図鑑は、ずっと無料です。広告もありません。", "The Village Pond (20 ponds), Today's Pond, Free fishing and the Fishbook stay free. No ads, ever."))
                .font(Theme.label(12)).foregroundStyle(Theme.cream).multilineTextAlignment(.center)
        }
    }

    private func feature(icon: AnyView, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            icon.frame(width: 110, height: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.label(16, weight: .heavy)).foregroundStyle(Theme.ink)
                Text(detail).font(Theme.body(12)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(PlankBackground(seed: UInt64(title.count)))
    }

    @ViewBuilder private var priceArea: some View {
        let store = model.purchases
        VStack(spacing: 10) {
            if model.isPro {
                Text(tr("Pro を使っています。ありがとう。", "You have Pro. Thank you.")).font(Theme.label(16, weight: .heavy)).foregroundStyle(Theme.ink)
            } else if let product = store.products.first {
                Button {
                    working = true
                    Task {
                        let outcome = await store.purchase(product)
                        working = false
                        switch outcome {
                        case .purchased: message = tr("ありがとう。新しい釣り場が開いた。", "Thank you. New spots are open.")
                        case .pending: message = tr("承認を待っています。", "Waiting for approval.")
                        case .failed: message = tr("購入できませんでした。時間をおいて、もう一度。", "The purchase didn't go through. Please try again later.")
                        case .cancelled: break
                        }
                    }
                } label: {
                    Text(trf("%@ で Pro にする", "Get Pro for %@", product.displayPrice))
                }
                .buttonStyle(PlankButtonStyle(prominent: true))
                .disabled(working)
                .accessibilityIdentifier("paywall.buy")
            } else if store.loadState == .loading || store.loadState == .idle {
                ProgressView().tint(Theme.ink)
                Text(tr("値段を読み込んでいます…", "Loading the price…")).font(Theme.label(12)).foregroundStyle(Theme.inkSoft)
            } else {
                Text(tr("いまは購入できません。通信できる所で、あとでもう一度開いてください。", "Purchases aren't available right now. Please try again later with a connection."))
                    .font(Theme.label(13)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
                Button(tr("もう一度読み込む", "Try again")) { Task { await store.load() } }
                    .buttonStyle(PlankButtonStyle())
            }
            if let message {
                Text(message).font(Theme.label(13, weight: .bold)).foregroundStyle(Theme.bobberDeep)
            }
            Button(tr("購入を復元", "Restore purchases")) {
                Task {
                    await store.restore()
                    message = model.isPro ? tr("Pro を復元しました。", "Pro restored.") : tr("復元できる購入は見つかりませんでした。", "No purchases to restore.")
                }
            }
            .buttonStyle(PlankButtonStyle())
            .accessibilityIdentifier("paywall.restore")
        }
        .padding(14)
        .background(PlankBackground(tone: Theme.plankLight, seed: 61))
    }
}

// MARK: - 過去の今日の池（Pro）

struct PastSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetFrame(title: tr("過去の今日の池", "Past daily ponds"), closeID: "main.closePast") {
            Text(tr("記録には残らない練習の池。見逃した日の盤を遊べる。", "Practice ponds — they don't change your records."))
                .font(Theme.label(13)).foregroundStyle(Theme.cream)
            ForEach(model.pastDays(), id: \.self) { key in
                Button {
                    dismiss()
                    model.startPast(key)
                } label: {
                    HStack {
                        Text(key).font(Theme.label(16, weight: .bold)).monospacedDigit()
                        Spacer()
                        if let r = model.progress.daily[key] {
                            Text(trf("%d / %d 匹", "%d / %d fish", r.caught, r.total)).font(Theme.label(13)).monospacedDigit()
                        } else {
                            Text(tr("まだ", "Not fished")).font(Theme.label(13))
                        }
                    }
                }
                .buttonStyle(PlankButtonStyle())
            }
        }
    }
}

// MARK: - 共有

/// 釣果カード（360×640 を 3 倍で書き出す）。いちばんの 1 匹の魚拓と、池の結果を色のマスで
struct ShareCard: View {
    let title: String
    let dateText: String
    let caught: Int
    let total: Int
    let best: Catch?
    let grid: [[Int]]

    var body: some View {
        ZStack {
            PondBackdrop()
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    BobberView(size: 26)
                    Text(tr("うおさがし", "Ripple Pond")).signStyle(26)
                }
                Text(title + "  " + dateText).font(Theme.label(13)).foregroundStyle(Theme.cream)
                Spacer(minLength: 0)
                VStack(spacing: 6) {
                    if let best, let sp = best.species {
                        FishView(species: sp, width: 230)
                            .rotationEffect(.degrees(-6))
                        Text(sp.name).font(Theme.sign(26)).foregroundStyle(Theme.ink)
                        Text(String(format: "%.1f cm", best.cm)).font(Theme.sign(40)).monospacedDigit().foregroundStyle(Theme.bobberDeep)
                    } else {
                        Text(tr("ボウズ", "Skunked")).font(Theme.sign(40)).foregroundStyle(Theme.ink)
                    }
                    Text(trf("%d / %d 匹", "%d / %d fish", caught, total)).font(Theme.label(18, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(PlankBackground(tone: Theme.plankLight, seed: 71))
                // 答えの見えない池の絵（釣った＝橙・逃げた＝赤・覗いた＝水色）
                VStack(spacing: 2) {
                    ForEach(Array(grid.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 2) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, v in
                                RoundedRectangle(cornerRadius: 2).fill(color(v)).frame(width: 14, height: 14)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                Text("#うおさがし").font(Theme.label(12)).foregroundStyle(Theme.cream)
            }
            .padding(24)
        }
        .frame(width: 360, height: 640)
    }

    private func color(_ v: Int) -> Color {
        switch v {
        case 1: Color(hex: 0xF0A04B)
        case 2: Theme.bobber
        case 3: Theme.leaf
        case 4: Color(hex: 0xC8E9E1)
        default: Color(hex: 0x2B8E8C)
        }
    }

    /// 池の状態を色の番号に（0 水面・1 釣った・2 逃げた・3 水草・4 覗いた）
    static func grid(_ pond: Pond) -> [[Int]] {
        (0..<pond.rows).map { r in
            (0..<pond.cols).map { c -> Int in
                let p = Pos(r, c)
                if pond.terrainAt(p) == .weed { return 3 }
                switch pond[p] {
                case .caught: return 1
                case .escaped: return 2
                case .open: return 4
                case .hidden: return 0
                }
            }
        }
    }
}

struct ShareSheet: View {
    @Environment(AppModel.self) private var model
    @State private var image: Image?

    var body: some View {
        SheetFrame(title: tr("釣果を共有", "Share your catch"), closeID: "main.closeShare") {
            card
                .scaleEffect(0.8)
                .frame(width: 288, height: 512)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            if let image {
                ShareLink(item: image, preview: SharePreview(tr("うおさがしの釣果", "My Ripple Pond catch"), image: image)) {
                    Label(tr("画像を共有", "Share image"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PlankButtonStyle(prominent: true))
                .accessibilityIdentifier("share.link")
            }
        }
        .task { render() }
    }

    private var card: ShareCard {
        if let o = model.shareOuting {
            let title: String
            switch o.kind {
            case .daily: title = tr("今日の池", "Today's Pond")
            case .level(let a, let n): title = a.name + " \(n + 1)"
            default: title = tr("気ままに", "Free fishing")
            }
            return ShareCard(title: title, dateText: model.todayKey, caught: o.catches.count, total: o.totalFish, best: o.bestCatch, grid: ShareCard.grid(o.pond))
        }
        let r = model.todayResult
        let best = r?.bestSpecies.map { Catch(speciesID: $0, cm: r?.bestCm ?? 0, pos: Pos(0, 0)) }
        return ShareCard(title: tr("今日の池", "Today's Pond"), dateText: model.todayKey, caught: r?.caught ?? 0, total: r?.total ?? 0, best: best, grid: [])
    }

    @MainActor private func render() {
        let renderer = ImageRenderer(content: card.environment(model))
        renderer.scale = 3
        if let ui = renderer.uiImage { image = Image(uiImage: ui) }
    }
}
