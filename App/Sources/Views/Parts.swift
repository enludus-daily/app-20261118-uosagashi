import SwiftUI

// MARK: - 池の水（背景）

/// 釣り堀の水面。光の網目（コースティクス）と、縁の水草。止まった絵（撮影で黒い丸が出ないよう、くり返しの動きは使わない）
struct PondBackdrop: View {
    var area: Area = .village

    var body: some View {
        let w = Theme.water(area)
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: [w.surface, w.deep]), startPoint: .zero, endPoint: CGPoint(x: size.width * 0.3, y: size.height)))
            // 光の網目
            var rng = SeededRandom(seed: 7)
            for _ in 0..<26 {
                let x = Double(rng.unit()) * size.width
                let y = Double(rng.unit()) * size.height
                let len = 40 + rng.unit() * 90
                var p = Path()
                p.move(to: CGPoint(x: x, y: y))
                p.addCurve(to: CGPoint(x: x + len, y: y + 6),
                           control1: CGPoint(x: x + len * 0.3, y: y - 10),
                           control2: CGPoint(x: x + len * 0.7, y: y + 14))
                ctx.stroke(p, with: .color(.white.opacity(0.10 + rng.unit() * 0.08)), lineWidth: 1.5 + rng.unit() * 2)
            }
            // 縁の睡蓮の葉
            let pads: [(CGFloat, CGFloat, CGFloat)] = [(0.04, 0.12, 34), (0.95, 0.30, 40), (0.08, 0.62, 28), (0.92, 0.82, 36), (0.18, 0.95, 24)]
            for (fx, fy, r) in pads {
                let c = CGPoint(x: size.width * fx, y: size.height * fy)
                ctx.fill(LilyPad.path(center: c, radius: r), with: .color(Theme.leaf.opacity(0.85)))
                ctx.stroke(LilyPad.path(center: c, radius: r), with: .color(Theme.leafDeep.opacity(0.6)), lineWidth: 1.2)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum LilyPad {
    /// 切れ込みのある丸い葉
    static func path(center c: CGPoint, radius r: CGFloat) -> Path {
        var p = Path()
        p.move(to: c)
        p.addArc(center: c, radius: r, startAngle: .degrees(-70), endAngle: .degrees(250), clockwise: false)
        p.closeSubpath()
        return p
    }
}

// MARK: - 木の板

/// 桟橋の板（木目と、下の縁の厚み、角の釘）。部品と同じ大きさに Canvas で描く（はみ出さない・押せる範囲を覆わない）
struct PlankBackground: View {
    var radius: CGFloat = Theme.plankRadius
    var tone: Color = Theme.plank
    var seed: UInt64 = 1

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Theme.plankEdge)
                .offset(y: 3)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [tone.opacity(0.98), tone], startPoint: .top, endPoint: .bottom))
                .overlay {
                    Canvas { ctx, size in
                        var rng = SeededRandom(seed: seed)
                        let lines = max(3, Int(size.height / 9))
                        for i in 0..<lines {
                            let y = (CGFloat(i) + 0.5) * size.height / CGFloat(lines) + CGFloat(rng.unit() * 3)
                            var p = Path()
                            p.move(to: CGPoint(x: 6, y: y))
                            p.addCurve(to: CGPoint(x: size.width - 6, y: y + CGFloat(rng.unit() * 4 - 2)),
                                       control1: CGPoint(x: size.width * 0.3, y: y - 3),
                                       control2: CGPoint(x: size.width * 0.7, y: y + 3))
                            ctx.stroke(p, with: .color(Theme.grain.opacity(0.45)), lineWidth: 1)
                        }
                        // 節
                        let knot = CGRect(x: size.width * (0.2 + rng.unit() * 0.6), y: size.height * 0.35, width: 10, height: 5)
                        ctx.stroke(Path(ellipseIn: knot), with: .color(Theme.plankDark.opacity(0.5)), lineWidth: 1)
                        // 釘
                        for pt in [CGPoint(x: 9, y: 9), CGPoint(x: size.width - 9, y: 9), CGPoint(x: 9, y: size.height - 9), CGPoint(x: size.width - 9, y: size.height - 9)] {
                            ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 2, y: pt.y - 2, width: 4, height: 4)), with: .color(Theme.plankEdge.opacity(0.55)))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                }
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.plankEdge.opacity(0.5), lineWidth: 1))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 板のボタン。prominent は赤い浮きの色（白いペンキの字）
struct PlankButtonStyle: ButtonStyle {
    var prominent = false
    var compact = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.label(compact ? 15 : 17, weight: .bold))
            .foregroundStyle(prominent ? Theme.cream : Theme.ink)
            .padding(.horizontal, compact ? 12 : 18)
            .frame(minHeight: compact ? 44 : 52)
            .frame(maxWidth: compact ? nil : .infinity)
            .background {
                if prominent {
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.plankRadius, style: .continuous).fill(Theme.bobberDeep).offset(y: 3)
                        RoundedRectangle(cornerRadius: Theme.plankRadius, style: .continuous).fill(Theme.bobber)
                        RoundedRectangle(cornerRadius: Theme.plankRadius, style: .continuous).stroke(.white.opacity(0.35), lineWidth: 1).padding(2)
                    }
                    .allowsHitTesting(false)
                } else {
                    PlankBackground(tone: Theme.plankLight)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .offset(y: configuration.isPressed ? 2 : 0)
            .opacity(enabled ? 1 : 0.5)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

// MARK: - 魚

/// 魚の形（横向き、頭が右）。shape：1 細長い・0 ふつう・-1 丸い
struct FishShape: Shape {
    var shape: Int = 0

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let bodyH: CGFloat = shape == 1 ? 0.42 : (shape == -1 ? 0.7 : 0.56)
        let top = rect.midY - h * bodyH / 2, bottom = rect.midY + h * bodyH / 2
        let tailX = rect.minX + w * 0.2
        var p = Path()
        // 頭
        p.move(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addCurve(to: CGPoint(x: tailX, y: rect.midY - h * 0.06),
                   control1: CGPoint(x: rect.maxX - w * 0.12, y: top - h * 0.08),
                   control2: CGPoint(x: rect.minX + w * 0.42, y: top))
        // 尾
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.12))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.06, y: rect.midY), control: CGPoint(x: rect.minX + w * 0.08, y: rect.midY - h * 0.14))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - h * 0.12), control: CGPoint(x: rect.minX + w * 0.08, y: rect.midY + h * 0.14))
        p.addLine(to: CGPoint(x: tailX, y: rect.midY + h * 0.06))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                   control1: CGPoint(x: rect.minX + w * 0.42, y: bottom),
                   control2: CGPoint(x: rect.maxX - w * 0.12, y: bottom + h * 0.08))
        p.closeSubpath()
        return p
    }
}

/// 魚の絵（種の色・ひれ・目・模様）。silhouette は図鑑のまだ釣っていない魚
struct FishView: View {
    let species: Species
    var width: CGFloat = 60
    var silhouette = false

    var body: some View {
        let h = width * 0.55
        ZStack {
            FishShape(shape: species.shape)
                .fill(silhouette ? AnyShapeStyle(Color.black.opacity(0.28)) :
                        AnyShapeStyle(LinearGradient(colors: [Color(hex: species.body).opacity(0.85), Color(hex: species.body)], startPoint: .top, endPoint: .bottom)))
            if !silhouette {
                // 背びれと尾の色
                FishShape(shape: species.shape)
                    .fill(Color(hex: species.fin))
                    .mask(alignment: .leading) { Rectangle().frame(width: width * 0.22) }
                // 腹の明るさ
                FishShape(shape: species.shape)
                    .fill(.white.opacity(0.22))
                    .mask(alignment: .bottom) { Rectangle().frame(height: h * 0.32) }
                // 側線
                Capsule().fill(Color(hex: species.fin).opacity(0.55))
                    .frame(width: width * 0.5, height: max(1, h * 0.05))
                    .offset(x: width * 0.05)
                // 目
                Circle().fill(.white).frame(width: h * 0.2, height: h * 0.2)
                    .overlay(Circle().fill(Color(hex: 0x1C1C1C)).frame(width: h * 0.11, height: h * 0.11))
                    .offset(x: width * 0.33, y: -h * 0.06)
            }
        }
        .frame(width: width, height: h)
        .accessibilityHidden(true)
    }
}

// MARK: - 浮き・波紋・糸

/// 赤白の浮き（長押しの印）
struct BobberView: View {
    var size: CGFloat = 26

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Theme.ink).frame(width: size * 0.08, height: size * 0.32)
            ZStack {
                Circle().fill(.white)
                Circle().fill(Theme.bobber)
                    .mask(alignment: .top) { Rectangle().frame(height: size * 0.5) }
                Circle().stroke(Theme.bobberDeep.opacity(0.6), lineWidth: 1)
                Circle().fill(.white.opacity(0.7)).frame(width: size * 0.18).offset(x: -size * 0.16, y: -size * 0.16)
            }
            .frame(width: size * 0.62, height: size * 0.62)
        }
        .accessibilityHidden(true)
    }
}

/// 数を表す波紋の輪（数が多いほど輪が増える。最大 3 本）
struct RippleRings: View {
    let count: Int
    let color: Color

    var body: some View {
        ZStack {
            ForEach(0..<min(count, 3), id: \.self) { i in
                Circle()
                    .stroke(color.opacity(0.32 - Double(i) * 0.08), lineWidth: 1.4)
                    .scaleEffect(0.5 + CGFloat(i) * 0.2)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 糸の残り（3 本）。切れた糸は短く垂れる
struct LinesView: View {
    let lines: Int
    var maxLines = Outing.maxLines

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<maxLines, id: \.self) { i in
                let alive = i < lines
                VStack(spacing: 0) {
                    Rectangle().fill(alive ? Theme.ink.opacity(0.7) : Theme.ink.opacity(0.25))
                        .frame(width: 1.5, height: alive ? 14 : 6)
                    if alive {
                        // 釣り針
                        Path { p in
                            p.move(to: CGPoint(x: 5, y: 0))
                            p.addLine(to: CGPoint(x: 5, y: 6))
                            p.addQuadCurve(to: CGPoint(x: 1, y: 6), control: CGPoint(x: 3, y: 11))
                        }
                        .stroke(Theme.ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .frame(width: 8, height: 10)
                    } else {
                        Text("×").font(Theme.label(10, weight: .black)).foregroundStyle(Theme.bobberDeep)
                    }
                }
                .frame(width: 12, height: 26, alignment: .top)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trf("糸 のこり %d 本", "%d lines left", lines))
    }
}

/// 星（釣り場の池の評価）。浮きの形の 3 つ
struct StarsView: View {
    let stars: Int
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < stars ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(i < stars ? Theme.sun : Theme.ink.opacity(0.3))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trf("星 %d", "%d stars", stars))
    }
}

/// シートの枠（木の板の見出しと、閉じるボタン）
struct SheetFrame<Content: View>: View {
    let title: String
    var area: Area = .village
    let closeID: String
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PondBackdrop(area: area).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    content()
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 30)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Text(title).signStyle(24).lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PlankButtonStyle(compact: true))
                .accessibilityLabel(tr("閉じる", "Close"))
                .accessibilityIdentifier(closeID)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(Theme.water(area).deep.opacity(0.92).ignoresSafeArea(edges: .top))
        }
    }
}

/// 板の上の小さな見出しと中身
struct PlankCard<Content: View>: View {
    var seed: UInt64 = 1
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PlankBackground(seed: seed))
    }
}
