import SwiftUI

/// 桟橋（ホーム）：今日の池・続きから・釣り場・気ままに。下に図鑑・記録・設定
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        ZStack {
            PondBackdrop().ignoresSafeArea()
            ScrollView {
                if hSize == .regular {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(spacing: 16) {
                            header
                            today
                            resumeCard
                        }
                        VStack(spacing: 16) {
                            areas
                            freePlay
                        }
                    }
                    .padding(20)
                } else {
                    VStack(spacing: 16) {
                        header
                        today
                        resumeCard
                        areas
                        freePlay
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
    }

    private var header: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                BobberView(size: 34)
                Text(tr("うおさがし", "Ripple Pond")).signStyle(38)
            }
            Text(tr("数を読んで、水の下の魚を釣る", "Read the ripples. Catch what's below."))
                .font(Theme.label(14)).foregroundStyle(Theme.cream)
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
    }

    // MARK: 今日の池

    private var today: some View {
        PlankCard(seed: 21) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("今日の池", "Today's Pond")).font(Theme.sign(24)).foregroundStyle(Theme.ink)
                Spacer()
                Text(model.todayKey).font(Theme.label(12)).foregroundStyle(Theme.inkSoft).monospacedDigit()
            }
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").foregroundStyle(Theme.bobber)
                Text(model.streak > 0 ? trf("%d 日つづけて釣っている", "%d-day streak", model.streak)
                                      : tr("だれが開いても同じ池。1 日 1 回", "Same pond for everyone. Once a day"))
                    .font(Theme.label(13)).foregroundStyle(Theme.ink)
            }
            WeekStrip()
            if let r = model.todayResult {
                HStack(spacing: 12) {
                    if let id = r.bestSpecies, let sp = Species.find(id) {
                        FishView(species: sp, width: 64)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trf("今日は %d / %d 匹", "Today: %d / %d fish", r.caught, r.total)).font(Theme.label(16, weight: .heavy)).foregroundStyle(Theme.ink)
                        Text(tr("また明日、新しい池が開く", "A new pond opens tomorrow")).font(Theme.label(12)).foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                }
                Button(tr("釣果を共有", "Share your catch")) { model.share(nil) }
                    .buttonStyle(PlankButtonStyle())
                    .accessibilityIdentifier("home.shareDaily")
            } else {
                Button {
                    model.startDaily()
                } label: {
                    Label(isDailyInProgress ? tr("今日の池の続き", "Continue today's pond") : tr("今日の池へ", "Fish today's pond"), systemImage: "figure.fishing")
                }
                .buttonStyle(PlankButtonStyle(prominent: true))
                .accessibilityIdentifier("main.daily")
            }
        }
    }

    private var isDailyInProgress: Bool {
        if let o = model.outing, o.kind == .daily(model.todayKey), !o.isOver { return true }
        return false
    }

    @ViewBuilder private var resumeCard: some View {
        if let o = model.outing, !o.isOver, o.kind != .daily(model.todayKey) {
            PlankCard(seed: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("続きから", "Resume")).font(Theme.label(16, weight: .heavy)).foregroundStyle(Theme.ink)
                        Text(trf("のこり %d 匹・糸 %d 本", "%d fish left · %d lines", o.hiddenFish, o.lines)).font(Theme.label(12)).foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                    Button(tr("池へ", "Go")) { model.resume() }
                        .buttonStyle(PlankButtonStyle(prominent: true, compact: true))
                        .accessibilityIdentifier("home.resume")
                }
            }
        }
    }

    // MARK: 釣り場

    private var areas: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("釣り場", "Fishing spots")).signStyle(22)
            ForEach(Area.allCases) { a in
                Button {
                    model.browsingArea = a
                    model.activeSheet = .area
                    model.pressTick += 1
                } label: {
                    AreaRow(area: a)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("area.\(a.rawValue)")
            }
            if model.isPro {
                Button(tr("過去の今日の池", "Past daily ponds")) { model.activeSheet = .past }
                    .buttonStyle(PlankButtonStyle())
                    .accessibilityIdentifier("home.past")
            }
        }
    }

    private var freePlay: some View {
        PlankCard(seed: 23) {
            Text(tr("気ままに", "Free fishing")).font(Theme.label(17, weight: .heavy)).foregroundStyle(Theme.ink)
            Text(tr("何度でも新しい池。記録は図鑑に残る", "A fresh pond every time. Catches still count")).font(Theme.label(12)).foregroundStyle(Theme.inkSoft)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { s in
                    Button([tr("小", "S"), tr("中", "M"), tr("大", "L")][s]) { model.startFree(s) }
                        .buttonStyle(PlankButtonStyle())
                        .accessibilityIdentifier("free.\(s)")
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            barButton("book.fill", tr("図鑑", "Fishbook"), "main.codex", .codex)
            barButton("chart.bar.fill", tr("記録", "Records"), "main.records", .records)
            barButton("gearshape.fill", tr("設定", "Settings"), "main.settings", .settings)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: 640)
    }

    private func barButton(_ icon: String, _ title: String, _ id: String, _ sheet: ActiveSheet) -> some View {
        Button {
            model.activeSheet = sheet
            model.pressTick += 1
        } label: {
            VStack(spacing: 1) {
                Image(systemName: icon).font(.system(size: 16, weight: .bold))
                Text(title).font(Theme.label(12, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(PlankButtonStyle())
        .accessibilityIdentifier(id)
    }
}

/// 釣り場の 1 行（水の色の小窓・名前・決まり・進み具合）
struct AreaRow: View {
    @Environment(AppModel.self) private var model
    let area: Area

    var body: some View {
        let w = Theme.water(area)
        let locked = area.isPro && !model.isPro
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [w.surface, w.deep], startPoint: .top, endPoint: .bottom))
                if let sp = area.species.last {
                    FishView(species: sp, width: 44, silhouette: (model.progress.species[sp.id]?.count ?? 0) == 0)
                }
            }
            .frame(width: 64, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(area.name).font(Theme.label(16, weight: .heavy)).foregroundStyle(Theme.ink)
                    if locked { Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(Theme.inkSoft) }
                }
                Text(area.rule).font(Theme.label(11)).foregroundStyle(Theme.inkSoft).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(model.progress.clearedCount(area))/\(Area.levelsPerArea)").font(Theme.label(15, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
                HStack(spacing: 2) {
                    Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(Theme.sun)
                    Text("\(model.progress.starTotal(area))").font(Theme.label(11)).monospacedDigit().foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .padding(12)
        .background(PlankBackground(seed: UInt64(area.rawValue.count)))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// この 7 日の今日の池（釣った割合の棒）
struct WeekStrip: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let week = model.lastWeek()
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(week, id: \.0) { key, r in
                VStack(spacing: 3) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3).fill(Theme.plankDark.opacity(0.25)).frame(height: 34)
                        if let r {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(r.cleared ? Theme.water(.village).surface : Theme.bobber.opacity(0.75))
                                .frame(height: max(4, 34 * CGFloat(r.caught) / CGFloat(max(1, r.total))))
                        }
                    }
                    Text(String(key.suffix(2))).font(Theme.label(10)).monospacedDigit()
                        .foregroundStyle(key == model.todayKey ? Theme.bobberDeep : Theme.inkSoft)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trf("この 7 日で今日の池を釣った日 %d 日", "Fished %d of the last 7 days", week.filter { $0.1 != nil }.count))
    }
}
