import SwiftUI

/// 釣りの終わり（池が空になった／糸が尽きた）。中身はスクロールし、ボタンは下に固定。見出しは上に空けて重ねない
struct ResultOverlay: View {
    @Environment(AppModel.self) private var model
    let outing: Outing
    @State private var shown = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 14) {
                        Text(outing.status == .cleared ? tr("池が空になった！", "Pond cleared!") : tr("糸が尽きた…", "Out of line…"))
                            .signStyle(30, color: outing.status == .cleared ? Theme.cream : Color(hex: 0xFFE2D6))
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                        if case .level = outing.kind, outing.status == .cleared {
                            StarsView(stars: outing.stars, size: 30)
                                .scaleEffect(shown > 0 ? 1 : 0.6)
                        }
                        summary
                        catchesCard
                        if !model.newSpecies.isEmpty || !model.newRecords.isEmpty { newsCard }
                    }
                    .padding(18)
                }
                .scrollBounceBehavior(.basedOnSize)
                buttons
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
                    .padding(.top, 8)
            }
            .background(RoundedRectangle(cornerRadius: Theme.sheetRadius, style: .continuous).fill(Theme.water(outing.area).deep.opacity(0.96)).allowsHitTesting(false))
            .overlay(RoundedRectangle(cornerRadius: Theme.sheetRadius, style: .continuous).stroke(Theme.plank, lineWidth: 3).allowsHitTesting(false))
            .frame(maxWidth: 520)
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .onAppear {
            if model.reduceMotion || model.still {
                shown = 1
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.2)) { shown = 1 }
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 0) {
            stat(trf("%d / %d", "%d / %d", outing.catches.count, outing.totalFish), tr("釣った", "Caught"))
            stat("\(outing.lines)", tr("のこりの糸", "Lines left"))
            stat(String(format: "%d:%02d", outing.seconds / 60, outing.seconds % 60), tr("時間", "Time"))
        }
        .padding(.vertical, 12)
        .background(PlankBackground(seed: 11))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.sign(24)).monospacedDigit().foregroundStyle(Theme.ink)
            Text(label).font(Theme.label(12)).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    private var catchesCard: some View {
        PlankCard(seed: 12) {
            Text(tr("釣果", "Your catch")).font(Theme.label(15, weight: .heavy)).foregroundStyle(Theme.ink)
            if outing.catches.isEmpty {
                Text(tr("今回は 1 匹も釣れなかった。0 のまわりから少しずつ読むと、魚の場所が決まっていく。", "No fish this time. Start from the zeros and the fish will reveal themselves."))
                    .font(Theme.body(13)).foregroundStyle(Theme.inkSoft)
            } else {
                let groups = Dictionary(grouping: outing.catches, by: \.speciesID)
                let order = outing.area.species.filter { groups[$0.id] != nil }
                ForEach(Array(order.enumerated()), id: \.element.id) { i, sp in
                    let list = groups[sp.id] ?? []
                    HStack(spacing: 10) {
                        FishView(species: sp, width: 54)
                            .offset(x: shown > 0 ? 0 : -30)
                            .opacity(shown > 0 ? 1 : 0)
                            .animation(model.reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7).delay(0.3 + Double(i) * 0.12), value: shown)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(sp.name).font(Theme.label(15, weight: .bold)).foregroundStyle(Theme.ink)
                            Text(trf("いちばん大きいのは %.1f cm", "Biggest: %.1f cm", list.map(\.cm).max() ?? 0))
                                .font(Theme.label(12)).foregroundStyle(Theme.inkSoft).monospacedDigit()
                        }
                        Spacer()
                        Text("×\(list.count)").font(Theme.sign(20)).foregroundStyle(Theme.ink).monospacedDigit()
                    }
                }
            }
        }
    }

    private var newsCard: some View {
        PlankCard(seed: 13) {
            ForEach(model.newSpecies, id: \.self) { id in
                if let sp = Species.find(id) {
                    Label(trf("図鑑に %@ が載った", "%@ added to your Fishbook", sp.name), systemImage: "book.fill")
                        .font(Theme.label(14, weight: .bold)).foregroundStyle(Theme.ink)
                }
            }
            ForEach(model.newRecords, id: \.self) { c in
                if let sp = c.species {
                    Label(trf("%@ の大きさの記録 %.1f cm", "New %@ record: %.1f cm", sp.name, c.cm), systemImage: "ruler.fill")
                        .font(Theme.label(14, weight: .bold)).foregroundStyle(Theme.bobberDeep)
                }
            }
        }
    }

    private var isDaily: Bool {
        if case .daily = outing.kind { return true }
        return false
    }

    @ViewBuilder private var buttons: some View {
        VStack(spacing: 10) {
            switch outing.kind {
            case .level(let a, let n):
                if outing.status == .cleared && n + 1 < Area.levelsPerArea {
                    Button(model.canPlay(a, n + 1) ? tr("次の池へ", "Next pond") : tr("この先は Pro で", "Continue with Pro")) { model.nextLevel() }
                        .buttonStyle(PlankButtonStyle(prominent: true))
                        .accessibilityIdentifier("main.next")
                } else {
                    Button(tr("もう一度", "Try again")) { model.retry() }
                        .buttonStyle(PlankButtonStyle(prominent: true))
                        .accessibilityIdentifier("main.retry")
                }
            case .free, .tutorial:
                Button(outing.kind == .tutorial ? tr("桟橋へ（ホーム）", "Back to the pier") : tr("新しい池", "New pond")) {
                    if outing.kind == .tutorial { model.leavePond() } else { model.retry() }
                }
                .buttonStyle(PlankButtonStyle(prominent: true))
                .accessibilityIdentifier("main.next")
            case .daily:
                Button(tr("釣果を共有", "Share your catch")) { model.share(outing) }
                    .buttonStyle(PlankButtonStyle(prominent: true))
                    .accessibilityIdentifier("main.share")
            }
            HStack(spacing: 10) {
                if outing.kind != .tutorial {
                    Button(tr("桟橋に戻る", "To the pier")) { model.leavePond() }
                        .buttonStyle(PlankButtonStyle())
                        .accessibilityIdentifier("main.home")
                }
                if !isDaily && outing.kind != .tutorial {
                    Button(tr("共有", "Share")) { model.share(outing) }
                        .buttonStyle(PlankButtonStyle())
                        .accessibilityIdentifier("result.share")
                }
            }
        }
    }
}

/// 一時停止
struct PauseOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { model.showPause = false }
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                Text(tr("ひと休み", "Taking a break")).signStyle(28)
                Text(tr("池はこのまま残る。あとで続きから釣れる。", "The pond will wait for you. Come back any time."))
                    .font(Theme.label(14)).foregroundStyle(Theme.cream).multilineTextAlignment(.center)
                Button(tr("続ける", "Keep fishing")) { model.showPause = false }
                    .buttonStyle(PlankButtonStyle(prominent: true))
                    .accessibilityIdentifier("main.resume")
                Button(tr("桟橋に戻る", "To the pier")) { model.leavePond() }
                    .buttonStyle(PlankButtonStyle())
                    .accessibilityIdentifier("main.leave")
                Button(tr("遊び方", "How to play")) {
                    model.showPause = false
                    model.leavePond()
                    model.onboarded = false
                }
                .buttonStyle(PlankButtonStyle())
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: Theme.sheetRadius, style: .continuous).fill(Theme.water(.village).deep.opacity(0.97)).allowsHitTesting(false))
            .overlay(RoundedRectangle(cornerRadius: Theme.sheetRadius, style: .continuous).stroke(Theme.plank, lineWidth: 3).allowsHitTesting(false))
            .frame(maxWidth: 420)
            .padding(24)
        }
    }
}
