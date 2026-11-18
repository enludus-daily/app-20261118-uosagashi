import SwiftUI

/// 池の画面（盤・道具・糸・のこりの魚）。Duo の内側など広い画面では、右に魚図鑑と釣った魚
struct PondView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        if let o = model.outing {
            ZStack {
                PondBackdrop(area: o.area).ignoresSafeArea()
                GeometryReader { geo in
                    if hSize == .regular {
                        HStack(alignment: .top, spacing: 20) {
                            board(o, in: CGSize(width: geo.size.width * 0.62, height: geo.size.height))
                                .frame(width: geo.size.width * 0.62, height: geo.size.height)
                            SidePanel(outing: o)
                                .frame(maxHeight: geo.size.height)
                        }
                        .padding(.horizontal, 20)
                    } else {
                        board(o, in: geo.size)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                if let b = model.banner {
                    BannerView(banner: b).id(b.id)
                        .allowsHitTesting(false)
                }
                if model.showResult {
                    ResultOverlay(outing: o)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(2)
                }
                if model.showPause {
                    PauseOverlay().zIndex(3)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { TopBar(outing: o) }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !o.isOver { ToolBar(outing: o) }
            }
            .animation(model.reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: model.showResult)
            .task(id: o.isOver) { await tick() }
        }
    }

    private func board(_ o: Outing, in size: CGSize) -> some View {
        let pad: CGFloat = 16
        let side = floor(min((size.width - pad * 2) / CGFloat(o.pond.cols), (size.height - 40) / CGFloat(o.pond.rows)) * 0.9)
        return BoardView(outing: o, side: max(24, min(side, 72)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 経った時間（秒）。撮影・デモでは止める
    private func tick() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard !model.still, !model.showPause, var o = model.outing, !o.isOver, model.inPond else { continue }
            o.seconds += 1
            model.outing = o
        }
    }
}

/// 上の帯：戻る・池の名前・糸・のこりの魚
struct TopBar: View {
    @Environment(AppModel.self) private var model
    let outing: Outing

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.showPause = true
            } label: {
                Image(systemName: "pause.fill").font(.system(size: 15, weight: .bold)).frame(width: 44, height: 44)
            }
            .buttonStyle(PlankButtonStyle(compact: true))
            .accessibilityLabel(tr("一時停止", "Pause"))
            .accessibilityIdentifier("main.pause")
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Theme.label(15, weight: .heavy)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
                Text(trf("のこり %d 匹", "%d fish left", outing.hiddenFish))
                    .font(Theme.label(12)).foregroundStyle(Theme.inkSoft).monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("pond.left")
            }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                Image(systemName: "fish.fill").font(.system(size: 12)).foregroundStyle(Theme.bobber)
                Text("\(outing.catches.count)").font(Theme.label(16, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(trf("釣った魚 %d 匹", "%d caught", outing.catches.count))
            LinesView(lines: outing.lines)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(PlankBackground(radius: 14, seed: 3))
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .animation(.default, value: outing.catches.count)
    }

    private var title: String {
        switch outing.kind {
        case .daily: tr("今日の池", "Today's Pond")
        case .level(let a, let n): a.name + " " + trf("%d", "%d", n + 1)
        case .free(let s): [tr("気ままに・小さな池", "Free · Small"), tr("気ままに・中くらいの池", "Free · Medium"), tr("気ままに・大きな池", "Free · Large")][min(max(s, 0), 2)]
        case .tutorial: tr("はじめての池", "Your first pond")
        }
    }
}

/// 下の帯：のぞく／釣るの道具と、ヒント
struct ToolBar: View {
    @Environment(AppModel.self) private var model
    let outing: Outing

    var body: some View {
        VStack(spacing: 6) {
            Text(model.tool == .peek ? tr("タップで覗く・長押しで浮き", "Tap to peek · Hold to set a float")
                                     : tr("魚がいると読んだマスをタップして釣る", "Tap where you know a fish is"))
                .font(Theme.label(12)).foregroundStyle(Theme.cream)
                .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                .lineLimit(1).minimumScaleFactor(0.7)
            HStack(spacing: 10) {
                toolButton(.peek, icon: "eye", title: tr("のぞく", "Peek"), id: "main.toolPeek")
                toolButton(.rod, icon: "fish", title: tr("釣る", "Cast"), id: "main.toolRod")
                Button {
                    model.useHint()
                } label: {
                    VStack(spacing: 0) {
                        Image(systemName: "lightbulb.fill").font(.system(size: 17, weight: .bold))
                        Text("\(outing.hintsLeft)").font(Theme.label(12, weight: .heavy)).monospacedDigit()
                    }
                    .frame(width: 44)
                }
                .buttonStyle(PlankButtonStyle(compact: true))
                .accessibilityLabel(trf("ヒント のこり %d", "Hint, %d left", outing.hintsLeft))
                .accessibilityIdentifier("main.hint")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .frame(maxWidth: 560)
    }

    private func toolButton(_ t: Tool, icon: String, title: String, id: String) -> some View {
        let on = model.tool == t
        return Button {
            model.tool = t
            model.pressTick += 1
        } label: {
            HStack(spacing: 6) {
                Image(systemName: on ? icon + ".fill" : icon).font(.system(size: 17, weight: .bold))
                Text(title)
            }
        }
        .buttonStyle(PlankButtonStyle(prominent: on))
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}

/// 盤の上の一言（ぬし・逃げた・空振り）
struct BannerView: View {
    let banner: Banner
    @Environment(AppModel.self) private var model
    @State private var shown = false

    var body: some View {
        VStack(spacing: 2) {
            Text(banner.text).signStyle(26).multilineTextAlignment(.center)
            if !banner.sub.isEmpty {
                Text(banner.sub).font(Theme.label(14)).foregroundStyle(Theme.cream)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(Capsule().fill(Theme.water(.village).deep.opacity(0.88)))
        .scaleEffect(shown ? 1 : 0.6)
        .opacity(shown ? 1 : 0)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 70)
        .task {
            if model.still {
                shown = true
                return
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { shown = true }
            try? await Task.sleep(for: .milliseconds(1500))
            withAnimation(.easeOut(duration: 0.3)) { shown = false }
        }
    }
}

/// 広い画面の右：この釣り場の魚と、釣った魚
struct SidePanel: View {
    @Environment(AppModel.self) private var model
    let outing: Outing

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(outing.area.name).signStyle(22)
                Text(outing.area.rule).font(Theme.label(13)).foregroundStyle(Theme.cream.opacity(0.9))
                PlankCard(seed: 5) {
                    Text(tr("この池の魚", "Fish in this water")).font(Theme.label(14, weight: .heavy)).foregroundStyle(Theme.ink)
                    ForEach(outing.area.species) { sp in
                        let rec = model.progress.species[sp.id]
                        HStack(spacing: 10) {
                            FishView(species: sp, width: 46, silhouette: (rec?.count ?? 0) == 0 && !outing.catches.contains { $0.speciesID == sp.id })
                            VStack(alignment: .leading, spacing: 1) {
                                Text(sp.name).font(Theme.label(14, weight: .bold)).foregroundStyle(Theme.ink)
                                Text(sp.isLunker ? tr("ぬし・2 匹ぶん", "Lunker · counts 2") : (sp.school ? tr("群れ・横に 3 匹", "School · 3 in a row") : tr("小魚・1 匹", "Minnow · counts 1")))
                                    .font(Theme.label(11)).foregroundStyle(Theme.inkSoft)
                            }
                            Spacer()
                            Text("\(outing.catches.filter { $0.speciesID == sp.id }.count)").font(Theme.label(16, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
                        }
                    }
                }
                PlankCard(seed: 9) {
                    Text(tr("この池で釣った魚", "Caught here")).font(Theme.label(14, weight: .heavy)).foregroundStyle(Theme.ink)
                    if outing.catches.isEmpty {
                        Text(tr("まだ釣っていない。数が多いマスのまわりを読もう。", "Nothing yet. Read around the big numbers."))
                            .font(Theme.body(13)).foregroundStyle(Theme.inkSoft)
                    }
                    ForEach(Array(outing.catches.enumerated().reversed()), id: \.offset) { _, c in
                        HStack {
                            Text(c.species?.name ?? "").font(Theme.label(13)).foregroundStyle(Theme.ink)
                            Spacer()
                            Text(String(format: "%.1f cm", c.cm)).font(Theme.label(13, weight: .bold)).monospacedDigit().foregroundStyle(Theme.ink)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }
}
