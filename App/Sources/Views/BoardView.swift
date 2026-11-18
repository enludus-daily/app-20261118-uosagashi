import SwiftUI

/// 池の盤。マスは水面、覗くと水が透けて底と数（波紋の輪）が見える
struct BoardView: View {
    @Environment(AppModel.self) private var model
    let outing: Outing
    let side: CGFloat

    var body: some View {
        let pond = outing.pond
        let cols = pond.cols, rows = pond.rows
        let gap: CGFloat = max(2, side * 0.06)
        let w = Theme.water(outing.area)
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                // 池の縁（石と土手）
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(w.deep)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: 0x8C7A5A), lineWidth: 4))
                    .allowsHitTesting(false)
                VStack(spacing: gap) {
                    ForEach(0..<rows, id: \.self) { r in
                        HStack(spacing: gap) {
                            ForEach(0..<cols, id: \.self) { c in
                                let p = Pos(r, c)
                                TileView(pond: pond, pos: p, area: outing.area, side: side,
                                         delay: model.openDelays[p] ?? 0,
                                         hinted: model.hintPos == p, hintFish: model.hintIsFish,
                                         scared: model.scaredPos == p, missed: model.missedPos == p,
                                         over: outing.isOver)
                                    .frame(width: side, height: side)
                            }
                        }
                    }
                }
                .padding(gap + 3)
                // 釣れた魚が跳ねる
                if let s = model.splash {
                    SplashView(splash: s, side: side)
                        .offset(x: gap + 3 + CGFloat(s.pos.c) * (side + gap), y: gap + 3 + CGFloat(s.pos.r) * (side + gap))
                        .id(s.id)
                        .allowsHitTesting(false)
                }
            }
            .fixedSize()
            .modifier(ShakeEffect(shakes: CGFloat(model.shake)))
            .animation(model.reduceMotion ? nil : .linear(duration: 0.45), value: model.shake)
            // 桟橋（ここから始まる）
            PierView(width: side * 1.4)
                .offset(x: (CGFloat(pond.pier.c) + 0.5 - CGFloat(cols) / 2) * (side + gap))
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board")
    }
}

/// 揺れ（減衰。0,-9,8,-6,5,-3,2,0）
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = shakes - shakes.rounded(.down)
        let keys: [CGFloat] = [0, -9, 8, -6, 5, -3, 2, 0]
        let x = t == 0 ? 0 : keys[min(keys.count - 1, Int(t * CGFloat(keys.count - 1)))]
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

/// 桟橋
struct PierView: View {
    let width: CGFloat
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2).fill(i % 2 == 0 ? Theme.plank : Theme.plankLight)
                    .frame(width: width, height: 7)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.plankEdge.opacity(0.6), lineWidth: 1))
            }
        }
        .padding(.top, 2)
        .accessibilityHidden(true)
    }
}

/// 1 マス
struct TileView: View {
    @Environment(AppModel.self) private var model
    let pond: Pond
    let pos: Pos
    let area: Area
    let side: CGFloat
    let delay: Double
    let hinted: Bool
    let hintFish: Bool
    let scared: Bool
    let missed: Bool
    let over: Bool

    /// 表に出している状態（めくりの途中で入れ替える）
    @State private var shown: CellState?
    @State private var flip: Double = 0
    @State private var lift: CGFloat = 1

    var body: some View {
        let state = pond[pos]
        let current = shown ?? state
        tileFace(current)
            .rotation3DEffect(.degrees(flip), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .scaleEffect(lift)
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.35)
                    .onEnded { _ in model.longPress(pos) }
                    .exclusively(before: TapGesture().onEnded { model.tap(pos) })
            )
            .onChange(of: state) { old, new in reveal(from: old, to: new) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("tile.\(pos.r).\(pos.c)")
            .accessibilityAction { model.tap(pos) }
            .accessibilityAction(named: tr("浮きを置く", "Toggle float")) { model.longPress(pos) }
    }

    private func reveal(from old: CellState, to new: CellState) {
        guard old == .hidden, new != .hidden else {
            shown = nil
            return
        }
        if model.reduceMotion || model.still {
            shown = nil
            return
        }
        // 260ms：0→90°（水面）→ 面を入れ替える → 0°。途中で少し浮く
        shown = .hidden
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            withAnimation(.easeIn(duration: 0.13)) {
                flip = 90
                lift = 1.12
            }
            try? await Task.sleep(for: .milliseconds(130))
            shown = nil
            flip = -90
            withAnimation(.easeOut(duration: 0.13)) {
                flip = 0
                lift = 1
            }
        }
    }

    private var label: String {
        let t = pond.terrainAt(pos)
        if t == .weed { return tr("水草", "Weeds") }
        switch pond[pos] {
        case .hidden:
            if over && pond.hasFish(pos) { return tr("逃げた魚", "A fish that got away") }
            return pond.floats.contains(pos) ? tr("浮き", "Float") : (t == .ice ? tr("氷", "Ice") : tr("水面", "Water"))
        case .open:
            return t == .ice ? tr("氷の下は空", "Empty under the ice") : trf("魚 %d", "%d fish nearby", pond.number(at: pos))
        case .caught: return tr("釣った", "Caught")
        case .escaped: return tr("逃げた", "Escaped")
        }
    }

    @ViewBuilder private func tileFace(_ s: CellState) -> some View {
        let w = Theme.water(area)
        let t = pond.terrainAt(pos)
        ZStack {
            if t == .weed {
                RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous).fill(w.deep.opacity(0.9))
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    ctx.fill(LilyPad.path(center: c, radius: size.width * 0.38), with: .color(Theme.leaf))
                    ctx.stroke(LilyPad.path(center: c, radius: size.width * 0.38), with: .color(Theme.leafDeep), lineWidth: 1)
                    var vein = Path()
                    vein.move(to: c)
                    vein.addLine(to: CGPoint(x: c.x + size.width * 0.25, y: c.y + size.height * 0.1))
                    ctx.stroke(vein, with: .color(Theme.leafDeep.opacity(0.6)), lineWidth: 1)
                }
            } else if s == .hidden {
                hiddenFace(w, ice: t == .ice)
            } else {
                openFace(w, ice: t == .ice)
                switch s {
                case .caught:
                    if let sp = speciesHere { FishView(species: sp, width: side * 0.78).opacity(0.95) }
                case .escaped:
                    if let sp = speciesHere {
                        FishView(species: sp, width: side * 0.7, silhouette: true)
                        Text("!").font(Theme.sign(side * 0.36)).foregroundStyle(Theme.bobber).offset(x: side * 0.28, y: -side * 0.22)
                    }
                default:
                    if t == .water { numberFace }
                    if missed {
                        Text("×").font(Theme.sign(side * 0.3)).foregroundStyle(Theme.bobberDeep.opacity(0.7)).offset(x: side * 0.3, y: -side * 0.3)
                    }
                }
            }
            if hinted {
                RoundedRectangle(cornerRadius: Theme.tileRadius + 2, style: .continuous)
                    .stroke(Theme.sun, lineWidth: 3.5)
                    .shadow(color: Theme.sun.opacity(0.8), radius: 6)
                    .padding(-2)
                Image(systemName: hintFish ? "fish.fill" : "eye.fill")
                    .font(.system(size: side * 0.3, weight: .bold))
                    .foregroundStyle(Theme.sun)
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                    .offset(x: side * 0.3, y: -side * 0.3)
            }
        }
        .frame(width: side, height: side)
    }

    private var speciesHere: Species? {
        let i = pond.index(pos)
        guard pond.weight[i] > 0, let o = model.outing else { return nil }
        if let c = o.catches.first(where: { $0.pos == pos }) { return c.species }
        var col = pos.c
        while col - 1 >= 0 && pond.schooled[pond.index(Pos(pos.r, col - 1))] { col -= 1 }
        let key = pond.schooled[i] ? pond.index(Pos(pos.r, col + ((pos.c - col) / 3) * 3)) : i
        return Species.assign(area: area, seed: o.seed, index: i, weight: pond.weight[i], schooled: pond.schooled[i], schoolKey: key).0
    }

    @ViewBuilder private func hiddenFace(_ w: (surface: Color, deep: Color, clear: Color, bottom: Color), ice: Bool) -> some View {
        let seed = UInt64(pos.r * 31 + pos.c * 7 + 3)
        ZStack {
            RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous)
                .fill(ice ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xF3FAFC), Color(hex: 0xCFE4EC)], startPoint: .topLeading, endPoint: .bottomTrailing))
                          : AnyShapeStyle(LinearGradient(colors: [w.surface, w.surface.opacity(0.88)], startPoint: .top, endPoint: .bottom)))
            Canvas { ctx, size in
                var rng = SeededRandom(seed: seed)
                if ice {
                    // 氷のひび
                    var p = Path()
                    let start = CGPoint(x: size.width * (0.2 + rng.unit() * 0.3), y: size.height * 0.15)
                    p.move(to: start)
                    p.addLine(to: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
                    p.addLine(to: CGPoint(x: size.width * (0.6 + rng.unit() * 0.3), y: size.height * 0.85))
                    p.move(to: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
                    p.addLine(to: CGPoint(x: size.width * 0.9, y: size.height * (0.3 + rng.unit() * 0.2)))
                    ctx.stroke(p, with: .color(Color(hex: 0x8FB5C6).opacity(0.7)), lineWidth: 1)
                } else {
                    // 水面のきらめき（2 本の小さな弧）
                    for _ in 0..<2 {
                        let x = size.width * (0.15 + rng.unit() * 0.5)
                        let y = size.height * (0.2 + rng.unit() * 0.6)
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: y))
                        p.addQuadCurve(to: CGPoint(x: x + size.width * 0.28, y: y), control: CGPoint(x: x + size.width * 0.14, y: y - size.height * 0.1))
                        ctx.stroke(p, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    }
                }
            }
            if pond.floats.contains(pos) {
                Circle().stroke(.white.opacity(0.5), lineWidth: 1).frame(width: side * 0.6, height: side * 0.22).offset(y: side * 0.18)
                BobberView(size: side * 0.62).offset(y: -side * 0.04)
                    .transition(.offset(y: -side * 0.4).combined(with: .opacity))
            }
            if over && pond.hasFish(pos) {
                // 糸が尽きたあと：水の下にいた魚の影
                if let sp = speciesHere { FishView(species: sp, width: side * 0.7, silhouette: true).opacity(0.9) }
            }
        }
        .animation(model.reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.55), value: pond.floats.contains(pos))
    }

    @ViewBuilder private func openFace(_ w: (surface: Color, deep: Color, clear: Color, bottom: Color), ice: Bool) -> some View {
        let seed = UInt64(pos.r * 17 + pos.c * 13 + 5)
        ZStack {
            RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous)
                .fill(LinearGradient(colors: [w.clear, w.bottom.opacity(0.85)], startPoint: .top, endPoint: .bottom))
            // 底の小石
            Canvas { ctx, size in
                var rng = SeededRandom(seed: seed)
                for _ in 0..<3 {
                    let r = size.width * (0.06 + rng.unit() * 0.06)
                    let rect = CGRect(x: rng.unit() * (size.width - r * 2), y: size.height * 0.45 + rng.unit() * (size.height * 0.5 - r), width: r * 2.2, height: r * 1.4)
                    ctx.fill(Path(ellipseIn: rect), with: .color(w.deep.opacity(0.13)))
                }
            }
            if ice {
                RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous).fill(.white.opacity(0.35))
                Text("·").font(Theme.sign(side * 0.4)).foregroundStyle(Color(hex: 0x6E93A4))
            }
        }
    }

    @ViewBuilder private var numberFace: some View {
        let n = pond.number(at: pos)
        if n > 0 {
            ZStack {
                RippleRings(count: n, color: Theme.number(n)).frame(width: side * 0.95, height: side * 0.95)
                Text("\(n)")
                    .font(Theme.sign(side * 0.48))
                    .monospacedDigit()
                    .foregroundStyle(Theme.number(n))
            }
        }
    }
}

/// 釣れた瞬間：魚が水しぶきとともに跳ねる（固定の乱数で、毎回同じ散り方）
struct SplashView: View {
    let splash: Splash
    let side: CGFloat
    @Environment(AppModel.self) private var model
    @State private var phase: CGFloat = 0

    var body: some View {
        let sp = splash.speciesID.flatMap(Species.find)
        let jump = side * (splash.big ? 1.6 : 1.1)
        ZStack {
            // しぶき
            ForEach(0..<10, id: \.self) { i in
                let a = Double(i) / 10 * 2 * .pi + 0.3
                let d = side * (0.5 + CGFloat((i * 37) % 10) / 14) * phase
                Circle().fill(.white.opacity(0.9 * Double(1 - phase)))
                    .frame(width: side * 0.12, height: side * 0.12)
                    .offset(x: cos(a) * d, y: sin(a) * d * 0.6 - phase * side * 0.3)
            }
            Circle().stroke(.white.opacity(0.8 * Double(1 - phase)), lineWidth: 2)
                .frame(width: side * (0.4 + phase * 1.6), height: side * (0.2 + phase * 0.7))
            if let sp {
                FishView(species: sp, width: side * (splash.big ? 1.5 : 1.1))
                    .rotationEffect(.degrees(Double(-30 + phase * 60)))
                    .offset(y: -sin(phase * .pi) * jump)
                    .opacity(phase < 0.95 ? 1 : 0)
            }
        }
        .frame(width: side, height: side)
        .onAppear {
            if model.reduceMotion || model.still {
                phase = model.still ? 0.4 : 1
                return
            }
            withAnimation(.easeOut(duration: splash.big ? 0.9 : 0.65)) { phase = 1 }
        }
    }
}
