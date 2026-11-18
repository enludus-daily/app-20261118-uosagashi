import Foundation

/// 釣り場。村の釣り堀は無料、ほかの 3 つは Pro（渓流の 1 池目だけ 1 回お試しできる）
enum Area: String, Codable, CaseIterable, Sendable, Identifiable {
    case village, stream, shore, ice
    var id: String { rawValue }

    var name: String {
        switch self {
        case .village: tr("村の釣り堀", "Village Pond")
        case .stream: tr("山の渓流", "Mountain Stream")
        case .shore: tr("磯の潮だまり", "Tide Pools")
        case .ice: tr("氷の湖", "Frozen Lake")
        }
    }

    /// 釣り場の決まり（一言）
    var rule: String {
        switch self {
        case .village: tr("小魚・ぬし（2 匹ぶん）・群れ（横に 3 匹）", "Minnows, lunkers (count as 2), schools (3 in a row)")
        case .stream: tr("岩が多い。ぬしが多く、群れは早瀬にいる", "Rocky. More lunkers, schools in the rapids")
        case .shore: tr("広い潮だまり。ぬしが 2 匹ぶん、群れが多い", "Wide pools. Many lunkers and big schools")
        case .ice: tr("氷のマスは、覗いても数が見えない", "Ice tiles hide their number when peeked")
        }
    }

    var isPro: Bool { self != .village }

    static let levelsPerArea = 20

    /// 水の色（表面・深い所・透けた所・底）
    var water: (surface: UInt32, deep: UInt32, clear: UInt32, bottom: UInt32) {
        switch self {
        case .village: (0x37A9A2, 0x1D7A7E, 0xC2EADF, 0xEADFC0)
        case .stream: (0x47B4CF, 0x23799A, 0xD2F0F5, 0xDAD5C8)
        case .shore: (0x2D88BC, 0x184F7C, 0xB0DAEC, 0xEBDCB4)
        case .ice: (0x8FC3D6, 0x55889F, 0xE6F3F7, 0xCCD8DE)
        }
    }

    var species: [Species] { Species.all.filter { $0.area == self } }

    /// 池ごとの作り（手で決めた表）
    func spec(_ level: Int) -> PondSpec {
        let i = max(0, min(level, Self.levelsPerArea - 1))
        switch self {
        case .village:
            let table: [PondSpec] = [
                PondSpec(rows: 7, cols: 7, small: 4),
                PondSpec(rows: 7, cols: 7, small: 5),
                PondSpec(rows: 8, cols: 7, small: 6, weeds: 1),
                PondSpec(rows: 8, cols: 8, small: 7, weeds: 2),
                PondSpec(rows: 9, cols: 8, small: 8, weeds: 2),
                PondSpec(rows: 9, cols: 8, small: 6, big: 1, weeds: 2),
                PondSpec(rows: 9, cols: 8, small: 7, big: 2, weeds: 2),
                PondSpec(rows: 10, cols: 8, small: 9, big: 1, weeds: 3),
                PondSpec(rows: 10, cols: 8, small: 8, big: 2, weeds: 3),
                PondSpec(rows: 10, cols: 9, small: 10, big: 2, weeds: 3),
                PondSpec(rows: 10, cols: 9, small: 6, big: 1, schools: 1, weeds: 3),
                PondSpec(rows: 10, cols: 9, small: 7, big: 2, schools: 1, weeds: 3),
                PondSpec(rows: 11, cols: 9, small: 9, big: 2, schools: 1, weeds: 3),
                PondSpec(rows: 11, cols: 9, small: 7, big: 2, schools: 2, weeds: 3),
                PondSpec(rows: 11, cols: 9, small: 10, big: 3, schools: 1, weeds: 4),
                PondSpec(rows: 11, cols: 9, small: 8, big: 3, schools: 2, weeds: 4),
                PondSpec(rows: 11, cols: 9, small: 11, big: 3, schools: 1, weeds: 3),
                PondSpec(rows: 11, cols: 9, small: 9, big: 4, schools: 2, weeds: 3),
                PondSpec(rows: 11, cols: 9, small: 12, big: 3, schools: 2, weeds: 2),
                PondSpec(rows: 11, cols: 9, small: 11, big: 4, schools: 2, weeds: 2),
            ]
            return table[i]
        case .stream:
            // 岩（水草と同じ扱い）が多く、ぬしが多い
            let rows = i < 4 ? 9 : (i < 10 ? 10 : 11)
            let cols = i < 4 ? 8 : 9
            return PondSpec(rows: rows, cols: cols, small: 5 + i / 3, big: 1 + i / 5, schools: i < 6 ? 0 : 1 + i / 12, weeds: 5 + i / 4)
        case .shore:
            let rows = i < 3 ? 10 : 11
            return PondSpec(rows: rows, cols: 9, small: 6 + i / 3, big: 2 + i / 5, schools: 1 + i / 8, weeds: 2)
        case .ice:
            let rows = i < 3 ? 9 : (i < 8 ? 10 : 11)
            let cols = i < 3 ? 8 : 9
            return PondSpec(rows: rows, cols: cols, small: 6 + i / 3, big: i < 4 ? 0 : 1 + i / 7, schools: i < 8 ? 0 : 1, weeds: 1, ice: 2 + i / 4)
        }
    }
}

/// 魚（図鑑の 1 種）
struct Species: Identifiable, Equatable, Sendable {
    let id: String
    let area: Area
    let nameJa: String
    let nameEn: String
    /// 2 = ぬし（まわりの数に 2 匹ぶん）
    let weight: Int
    /// 群れで泳ぐ（横に 3 匹）
    let school: Bool
    let minCm: Int
    let maxCm: Int
    let body: UInt32
    let fin: UInt32
    /// 体の形（1 = 細長い、0 = ふつう、-1 = 丸い）
    let shape: Int
    let noteJa: String
    let noteEn: String

    var name: String { Lang.isJapanese ? nameJa : nameEn }
    var note: String { Lang.isJapanese ? noteJa : noteEn }
    var isLunker: Bool { weight == 2 }

    static let all: [Species] = [
        // 村の釣り堀
        Species(id: "funa", area: .village, nameJa: "フナ", nameEn: "Crucian Carp", weight: 1, school: false, minCm: 12, maxCm: 30,
                body: 0x9C8A4E, fin: 0x6E5F33, shape: -1, noteJa: "釣り堀のいちばんの常連。丸い体で、浮きをゆっくり沈める。", noteEn: "The pond's most loyal regular. Round-bodied; sinks the float slowly."),
        Species(id: "tanago", area: .village, nameJa: "タナゴ", nameEn: "Bitterling", weight: 1, school: false, minCm: 4, maxCm: 9,
                body: 0xB7A6C9, fin: 0xD9607A, shape: -1, noteJa: "手のひらに乗る小ささ。光の当たり方で、うす紫に光る。", noteEn: "Small enough for your palm. Shimmers violet in the sun."),
        Species(id: "moroko", area: .village, nameJa: "モロコ", nameEn: "Gudgeon", weight: 1, school: true, minCm: 6, maxCm: 12,
                body: 0xB9B08A, fin: 0x7F7656, shape: 1, noteJa: "いつも 3 匹で横に並んで泳ぐ。1 匹見つけたら、となりを読む。", noteEn: "Always swims three abreast. Find one, then read its neighbors."),
        Species(id: "namazu", area: .village, nameJa: "ナマズ", nameEn: "Catfish", weight: 2, school: false, minCm: 40, maxCm: 75,
                body: 0x4F5A45, fin: 0x343C2D, shape: 1, noteJa: "ぬし。ひげで底を探る。まわりの数には 2 匹ぶんで映る。", noteEn: "A lunker. Feels the bottom with its whiskers. Counts as two."),
        Species(id: "koi", area: .village, nameJa: "ぬしのコイ", nameEn: "Old Koi", weight: 2, school: false, minCm: 55, maxCm: 95,
                body: 0xE07B3C, fin: 0xF4E3C9, shape: 0, noteJa: "池のぬし。何十年もここにいるらしい。2 匹ぶんの重さ。", noteEn: "The pond's elder. Rumored to be decades old. Counts as two."),
        // 山の渓流
        Species(id: "yamame", area: .stream, nameJa: "ヤマメ", nameEn: "Masu Trout", weight: 1, school: false, minCm: 15, maxCm: 30,
                body: 0xA7B3A0, fin: 0x6B7F8E, shape: 1, noteJa: "体の横に小判のような模様。冷たい淵にひそむ。", noteEn: "Oval parr marks down its side. Hides in cold pools."),
        Species(id: "kajika", area: .stream, nameJa: "カジカ", nameEn: "Sculpin", weight: 1, school: false, minCm: 8, maxCm: 15,
                body: 0x8A7A5E, fin: 0x5E523E, shape: -1, noteJa: "石の下が家。岩のとなりのマスを疑え。", noteEn: "Lives under stones. Suspect the tiles next to rocks."),
        Species(id: "ayu", area: .stream, nameJa: "アユ", nameEn: "Sweetfish", weight: 1, school: true, minCm: 12, maxCm: 25,
                body: 0xB8C2A8, fin: 0xE8C547, shape: 1, noteJa: "早瀬に 3 匹並ぶ。スイカのような香りがするという。", noteEn: "Lines up three-wide in the rapids. Said to smell of melon."),
        Species(id: "iwana", area: .stream, nameJa: "イワナ", nameEn: "Char", weight: 2, school: false, minCm: 35, maxCm: 60,
                body: 0x6F6A55, fin: 0xD98A4E, shape: 1, noteJa: "渓流のぬし。岩陰で動かない。2 匹ぶん。", noteEn: "Lord of the stream. Waits motionless behind rocks. Counts as two."),
        Species(id: "nijimasu", area: .stream, nameJa: "ニジマス", nameEn: "Rainbow Trout", weight: 2, school: false, minCm: 40, maxCm: 70,
                body: 0x9AA6A8, fin: 0xD86D82, shape: 0, noteJa: "体に虹色の帯。大きく育つと跳ねる。2 匹ぶん。", noteEn: "A rainbow band along its flank. Leaps when it's big. Counts as two."),
        // 磯の潮だまり
        Species(id: "mejina", area: .shore, nameJa: "メジナ", nameEn: "Opaleye", weight: 1, school: false, minCm: 15, maxCm: 35,
                body: 0x41566E, fin: 0x2B3A4C, shape: -1, noteJa: "磯釣りの定番。青い目が光る。", noteEn: "A tide-pool classic with glowing blue eyes."),
        Species(id: "kasago", area: .shore, nameJa: "カサゴ", nameEn: "Rockfish", weight: 1, school: false, minCm: 12, maxCm: 28,
                body: 0xC2563E, fin: 0x8E3424, shape: -1, noteJa: "岩のすきまでじっと待つ。とげに注意。", noteEn: "Waits in rock crevices. Mind the spines."),
        Species(id: "iwashi", area: .shore, nameJa: "イワシ", nameEn: "Sardine", weight: 1, school: true, minCm: 10, maxCm: 20,
                body: 0x8FA9C4, fin: 0x51708F, shape: 1, noteJa: "群れで 3 匹並んで、銀色にきらめく。", noteEn: "Flashes silver in schools of three."),
        Species(id: "madai", area: .shore, nameJa: "マダイ", nameEn: "Red Sea Bream", weight: 2, school: false, minCm: 40, maxCm: 80,
                body: 0xE38A8E, fin: 0x5FB4C9, shape: 0, noteJa: "めでたい魚。青い点が散る。2 匹ぶん。", noteEn: "A lucky fish dotted with blue. Counts as two."),
        Species(id: "suzuki", area: .shore, nameJa: "スズキ", nameEn: "Sea Bass", weight: 2, school: false, minCm: 50, maxCm: 90,
                body: 0x9EA9B0, fin: 0x5B6870, shape: 1, noteJa: "潮だまりのぬし。えら洗いで暴れる。2 匹ぶん。", noteEn: "Boss of the pools. Thrashes at the surface. Counts as two."),
        // 氷の湖
        Species(id: "wakasagi", area: .ice, nameJa: "ワカサギ", nameEn: "Pond Smelt", weight: 1, school: true, minCm: 6, maxCm: 13,
                body: 0xC9D5DC, fin: 0x8FA4B1, shape: 1, noteJa: "氷の下で 3 匹並ぶ。穴釣りの主役。", noteEn: "Lines up three-wide under the ice. Star of ice fishing."),
        Species(id: "himemasu", area: .ice, nameJa: "ヒメマス", nameEn: "Kokanee", weight: 1, school: false, minCm: 20, maxCm: 35,
                body: 0xA9BDCB, fin: 0xC96B5A, shape: 0, noteJa: "冷たい湖のまんなかを泳ぐ。", noteEn: "Cruises the middle of cold lakes."),
        Species(id: "ugui", area: .ice, nameJa: "ウグイ", nameEn: "Dace", weight: 1, school: false, minCm: 15, maxCm: 30,
                body: 0xB3AE9C, fin: 0xC9574A, shape: 1, noteJa: "寒さに強い。春には赤い線が出る。", noteEn: "Tough in the cold. Grows red stripes in spring."),
        Species(id: "itou", area: .ice, nameJa: "イトウ", nameEn: "Taimen", weight: 2, school: false, minCm: 70, maxCm: 130,
                body: 0x7D6A5B, fin: 0xB04A3E, shape: 1, noteJa: "幻の大魚。氷の下で何年も育つ。2 匹ぶん。", noteEn: "A legendary giant that grows for years under the ice. Counts as two."),
        Species(id: "amemasu", area: .ice, nameJa: "アメマス", nameEn: "White-spotted Char", weight: 2, school: false, minCm: 45, maxCm: 75,
                body: 0x5D6F78, fin: 0xE9EEF0, shape: 1, noteJa: "白い斑点が雪のよう。2 匹ぶん。", noteEn: "White spots like falling snow. Counts as two."),
    ]

    static func find(_ id: String) -> Species? { all.first { $0.id == id } }

    /// 池の魚の 1 匹が何の魚で、何 cm か（種とマスから毎回同じに決まる）
    static func assign(area: Area, seed: UInt64, index: Int, weight: Int, schooled: Bool, schoolKey: Int) -> (Species, Double) {
        let pool = area.species
        let candidates: [Species]
        if weight == 2 {
            candidates = pool.filter { $0.weight == 2 }
        } else if schooled {
            candidates = pool.filter { $0.school }
        } else {
            candidates = pool.filter { $0.weight == 1 && !$0.school }
        }
        var rng = SeededRandom(seed: seed &+ UInt64(index + 1) &* 0x2545_F491_4F6C_DD1D)
        // 群れは 3 匹とも同じ種
        var pick = SeededRandom(seed: seed &+ UInt64(schooled ? schoolKey + 7_777 : index + 1) &* 0x9E37_79B9)
        let list = candidates.isEmpty ? pool : candidates
        let sp = list[pick.below(list.count)]
        // 大きさ：ふつうは中くらいが多く、たまに記録級（上の 10%）
        let u = (rng.unit() + rng.unit()) / 2
        let lucky = rng.below(12) == 0
        let t = lucky ? 0.9 + rng.unit() * 0.1 : u * 0.9
        let cm = Double(sp.minCm) + Double(sp.maxCm - sp.minCm) * t
        return (sp, (cm * 10).rounded() / 10)
    }
}
