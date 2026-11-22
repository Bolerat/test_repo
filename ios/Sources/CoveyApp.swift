// 同窝 Covey · 应用入口
import SwiftUI

@main
struct CoveyApp: App {
    @StateObject private var store = Store.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
        }
    }
}

struct RootTabView: View {
    @EnvironmentObject var store: Store
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            TodayView()
                .tabItem { Label("今日", systemImage: "pawprint.fill") }
                .tag(0)
            JournalView()
                .tabItem { Label("记录", systemImage: "book.closed") }
                .tag(1)
            AIChatView()
                .tabItem { Label("AI 助手", systemImage: "wand.and.stars") }
                .tag(2)
            PetView()
                .tabItem { Label("宠物", systemImage: "cat") }
                .tag(3)
            MeView()
                .tabItem { Label("我的", systemImage: "person.circle") }
                .tag(4)
        }
        .tint(CoveyTheme.accent)
        .onReceive(NotificationCenter.default.publisher(for: .askAI)) { note in
            store.pendingAiPrompt = note.object as? String
            tab = 2
        }
    }
}

// MARK: - 主题

enum CoveyTheme {
    static let bg = Color(hex: 0xF6F3EC)
    static let card = Color(hex: 0xFFFDF8)
    static let ink = Color(hex: 0x33302A)
    static let ink2 = Color(hex: 0x7A7264)
    static let ink3 = Color(hex: 0xA89E8D)
    static let line = Color(hex: 0xEAE3D5)
    static let accent = Color(hex: 0xD96F4E)
    static let accentSoft = Color(hex: 0xFBE9E2)
    static let sage = Color(hex: 0x6F8F5F)
    static let sageSoft = Color(hex: 0xE9F0E4)
    static let gold = Color(hex: 0xC99A3F)
    static let goldSoft = Color(hex: 0xF7EED7)
    static let blue = Color(hex: 0x5B7FA6)
    static let blueSoft = Color(hex: 0xE6EDF5)
    static let danger = Color(hex: 0xC25B4E)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

func tagColor(_ type: String) -> Color {
    switch type {
    case "feeding", "spend": return CoveyTheme.accent
    case "water", "photo": return CoveyTheme.blue
    case "clean", "note": return CoveyTheme.sage
    case "walk", "care": return CoveyTheme.gold
    case "companion": return Color(hex: 0x7A5C8F)
    case "health": return CoveyTheme.danger
    default: return CoveyTheme.ink3
    }
}

func taskTypeLabel(_ type: String) -> String {
    ["feeding": "喂食", "water": "换水", "clean": "清洁", "walk": "遛弯", "companion": "陪伴"][type] ?? type
}

func weekdayCN(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.dateFormat = "M月d日 EEE"
    return f.string(from: d)
}

func fullDateCN(_ dateStr: String) -> String {
    guard let d = dateFormatterCN.date(from: dateStr) else { return dateStr }
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.dateFormat = "yyyy年M月d日"
    return f.string(from: d)
}

func fmtShortTime(_ ts: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "MM-dd HH:mm"
    return f.string(from: ts)
}
