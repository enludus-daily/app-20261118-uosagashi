import SwiftUI

/// はじめの案内（3 ページ。自前のページ送り）。最後に「はじめての池」へ
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var page = 0
    @State private var step = 0

    private var pages: [(String, String)] {
        [
            (tr("水の下に、魚がいる", "Fish hide under the water"),
             tr("マインスイーパーの推理で、魚を釣るパズル。運の 2 択はない。数を読めば、必ず釣れる。", "A logic puzzle like Minesweeper — but you're fishing. No coin flips: read the numbers and every fish can be found.")),
            (tr("覗くと、波紋が数を教える", "Peek, and the ripples count"),
             tr("覗いたマスには、まわり 8 マスにいる魚の数が出る。ぬし（大物）は 2 匹ぶん。", "A peeked tile shows how many fish are in the 8 tiles around it. Lunkers count as two.")),
            (tr("いると読んだら、竿を垂らす", "Know it's there? Cast."),
             tr("外す・魚を驚かせると糸が 1 本切れる。糸は 3 本。長押しで浮き（印）を置ける。記録はこの iPhone の中だけ。", "A miss or a spooked fish snaps a line — you have 3. Hold to set a float. Your records stay on this iPhone.")),
        ]
    }

    var body: some View {
        ZStack {
            PondBackdrop().ignoresSafeArea()
            VStack(spacing: 18) {
                HStack {
                    Spacer()
                    Button(tr("とばす", "Skip")) { finish(tutorial: false) }
                        .buttonStyle(PlankButtonStyle(compact: true))
                        .accessibilityIdentifier("onboarding.skip")
                }
                Spacer(minLength: 0)
                Illustration(page: page, step: step)
                    .frame(height: 230)
                    .id(page)
                VStack(spacing: 10) {
                    Text(pages[page].0).signStyle(28).multilineTextAlignment(.center)
                    Text(pages[page].1).font(Theme.label(15)).foregroundStyle(Theme.cream).multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 8)
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule().fill(i == page ? Theme.bobber : Theme.cream.opacity(0.5)).frame(width: i == page ? 22 : 8, height: 8)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .frame(maxWidth: 560)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(page < pages.count - 1 ? tr("次へ", "Next") : tr("はじめての池へ", "Fish your first pond")) {
                if page < pages.count - 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { page += 1 }
                } else {
                    finish(tutorial: true)
                }
            }
            .buttonStyle(PlankButtonStyle(prominent: true))
            .accessibilityIdentifier("main.onboardingNext")
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
            .frame(maxWidth: 560)
        }
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            if v.translation.width < -40 && page < pages.count - 1 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { page += 1 }
            } else if v.translation.width > 40 && page > 0 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { page -= 1 }
            }
        })
    }

    private func finish(tutorial: Bool) {
        model.onboarded = true
        if tutorial && !model.progress.tutorialDone { model.startTutorial() }
    }
}

/// 案内の絵（小さな 3×3 の池）。表示した時に 1 回だけ動く（くり返さない）
private struct Illustration: View {
    let page: Int
    let step: Int
    @Environment(AppModel.self) private var model
    @State private var phase: CGFloat = 0

    var body: some View {
        let w = Theme.water(.village)
        let side: CGFloat = 64
        ZStack {
            VStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { r in
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { c in
                            cell(r, c, w: w, side: side)
                        }
                    }
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 14).fill(w.deep).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: 0x8C7A5A), lineWidth: 4)))
        }
        .onAppear {
            phase = 0
            if model.reduceMotion || model.still {
                phase = 1
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.5)) { phase = 1 }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private func cell(_ r: Int, _ c: Int, w: (surface: Color, deep: Color, clear: Color, bottom: Color), side: CGFloat) -> some View {
        let koi = Species.find("koi")
        let funa = Species.find("funa")
        ZStack {
            switch page {
            case 0:
                RoundedRectangle(cornerRadius: 7).fill(w.surface)
                if (r, c) == (0, 2), let funa {
                    FishView(species: funa, width: 46, silhouette: true).offset(x: (1 - phase) * -20).opacity(0.3 + phase * 0.6)
                }
                if (r, c) == (2, 0), let koi {
                    FishView(species: koi, width: 50, silhouette: true).offset(x: (1 - phase) * 20).opacity(0.3 + phase * 0.6)
                }
            case 1:
                if r == 1 && c == 1 {
                    RoundedRectangle(cornerRadius: 7).fill(LinearGradient(colors: [w.clear, w.bottom], startPoint: .top, endPoint: .bottom))
                    RippleRings(count: 3, color: Theme.number(3)).scaleEffect(0.6 + phase * 0.4)
                    Text("3").font(Theme.sign(30)).foregroundStyle(Theme.number(3)).scaleEffect(0.6 + phase * 0.4)
                } else {
                    RoundedRectangle(cornerRadius: 7).fill(w.surface)
                    if (r, c) == (0, 0), let funa { FishView(species: funa, width: 44, silhouette: true).opacity(phase * 0.8) }
                    if (r, c) == (2, 2), let koi { FishView(species: koi, width: 48, silhouette: true).opacity(phase * 0.8) }
                }
            default:
                if (r, c) == (0, 0) {
                    RoundedRectangle(cornerRadius: 7).fill(LinearGradient(colors: [w.clear, w.bottom], startPoint: .top, endPoint: .bottom))
                    if let funa { FishView(species: funa, width: 50).offset(y: -phase * 10).rotationEffect(.degrees(Double(phase) * -15)) }
                } else if (r, c) == (1, 2) {
                    RoundedRectangle(cornerRadius: 7).fill(w.surface)
                    BobberView(size: 40).offset(y: (1 - phase) * -30).opacity(phase)
                } else {
                    RoundedRectangle(cornerRadius: 7).fill(r == 2 ? AnyShapeStyle(LinearGradient(colors: [w.clear, w.bottom], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(w.surface))
                    if r == 2 { Text("1").font(Theme.sign(26)).foregroundStyle(Theme.number(1)) }
                }
            }
        }
        .frame(width: side, height: side)
    }
}
