import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

/// 夏の朝の釣り堀の色・書体・形（ここだけで決める）。
/// 水（青緑の 4 段階：表面・深い所・透けた所・底の砂）、木の桟橋（板・濃い板・縁・木目）、赤白の浮き、水草の緑
enum Theme {
    // 木の桟橋
    static let plank = Color(hex: 0xDDAE72)
    static let plankLight = Color(hex: 0xEBC48F)
    static let plankDark = Color(hex: 0xB07A43)
    static let plankEdge = Color(hex: 0x7D512B)
    static let grain = Color(hex: 0xC9955A)
    /// 板に書いた字（こげ茶のペンキ）
    static let ink = Color(hex: 0x4A2E18)
    static let inkSoft = Color(hex: 0x6E4C2F)
    /// 看板の白いペンキ
    static let cream = Color(hex: 0xFFF7E8)
    // 浮き
    static let bobber = Color(hex: 0xE4523B)
    static let bobberDeep = Color(hex: 0xB33A27)
    // 水草
    static let leaf = Color(hex: 0x5FA04F)
    static let leafDeep = Color(hex: 0x3D7535)
    /// ヒントの光（朝日）
    static let sun = Color(hex: 0xFFD45C)
    static let sky = Color(hex: 0xE9F7F3)

    static func water(_ area: Area) -> (surface: Color, deep: Color, clear: Color, bottom: Color) {
        let w = area.water
        return (Color(hex: w.surface), Color(hex: w.deep), Color(hex: w.clear), Color(hex: w.bottom))
    }

    /// 数の色（多いほど深い水の色から、暖かい色へ）
    static func number(_ n: Int) -> Color {
        switch n {
        case 1: Color(hex: 0x1C6E8C)
        case 2: Color(hex: 0x2B7A3B)
        case 3: Color(hex: 0xC35E22)
        case 4: Color(hex: 0xA33A62)
        default: Color(hex: 0x5B2E86)
        }
    }

    // 書体：看板の丸い太字と、ふつうの丸ゴシック
    static func sign(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func label(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font { .system(size: size, weight: weight, design: .rounded) }
    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .rounded) }

    // 角丸の段階
    static let tileRadius: CGFloat = 7
    static let plankRadius: CGFloat = 12
    static let sheetRadius: CGFloat = 22
}

extension View {
    /// 看板の字（白いペンキに、こげ茶の影）
    func signStyle(_ size: CGFloat, color: Color = Theme.cream) -> some View {
        font(Theme.sign(size))
            .foregroundStyle(color)
            .shadow(color: Theme.plankEdge.opacity(0.9), radius: 0, x: 0, y: 2)
    }
}
