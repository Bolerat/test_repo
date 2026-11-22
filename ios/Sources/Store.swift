// 同窝 Covey · 数据模型与本地存储（UserDefaults 本机持久化）
import Foundation

// MARK: - 模型

struct Pet: Codable {
    var name = "布丁"
    var species = "cat"   // cat | dog | rabbit | other
    var breed = ""
    var birthday = ""      // YYYY-MM-DD
    var weight = ""        // kg 字符串（显示当前值，源自最新体重记录或手动编辑）
}

struct Member: Codable, Identifiable {
    var id: String
    var name: String
    var role: String      // owner | caregiver | viewer
}

enum EntryType: String, Codable {
    // care 仅用于兼容旧版本完成照护任务生成的记录，新版不再产生
    case care, note, photo, spend, health
    var label: String {
        switch self {
        case .care: return "照护"
        case .note: return "日常"
        case .photo: return "照片"
        case .spend: return "花费"
        case .health: return "健康"
        }
    }
    var symbol: String {
        switch self {
        case .care: return "checkmark.circle.fill"
        case .note: return "note.text"
        case .photo: return "camera.fill"
        case .spend: return "yensign.circle.fill"
        case .health: return "heart.text.square.fill"
        }
    }
}

struct Entry: Codable, Identifiable {
    var id: String
    var ts: Date
    var type: EntryType
    var text: String = ""
    var photoData: Data? = nil
    var amount: Double? = nil
    var by: String = "me"
    var taskId: String? = nil
}

enum ReminderCategory: String, Codable, CaseIterable {
    case vaccine, deworm, grooming, medical, custom
    var label: String {
        switch self {
        case .vaccine: return "疫苗"
        case .deworm: return "驱虫"
        case .grooming: return "洗护"
        case .medical: return "就诊"
        case .custom: return "自定义"
        }
    }
}

struct Reminder: Codable, Identifiable {
    var id: String
    var title: String
    var category: ReminderCategory
    var due: String        // YYYY-MM-DD
    var done = false
    var note = ""
}

struct WeightRecord: Codable, Identifiable {
    var id: String
    var date: String       // YYYY-MM-DD
    var kg: Double
}

struct AIConfig: Codable {
    var provider = "deepseek"
    var baseURL = "https://api.deepseek.com/v1"
    var apiKey = ""
    var model = "deepseek-chat"
    var tone = "warm"    // warm | lively | concise | calm，见 aiTones
    var configured: Bool { !apiKey.trimmed.isEmpty && !baseURL.trimmed.isEmpty }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        provider = try c.decodeIfPresent(String.self, forKey: .provider) ?? "deepseek"
        baseURL = try c.decodeIfPresent(String.self, forKey: .baseURL) ?? "https://api.deepseek.com/v1"
        apiKey = try c.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? "deepseek-chat"
        tone = try c.decodeIfPresent(String.self, forKey: .tone) ?? "warm"
    }
}

struct ChatMessage: Codable, Identifiable {
    var id: String
    var role: String       // user | assistant
    var content: String
    var ts: Date
    var pending = false
}

struct CoveyData: Codable {
    var pet = Pet()
    var activeMember = "me"
    var members: [Member] = [Member(id: "me", name: "我", role: "owner")]
    var entries: [Entry] = []
    var reminders: [Reminder] = []
    var remindersEnabled = true
    var weights: [WeightRecord] = []
    var ai = AIConfig()
    var chat: [ChatMessage] = []

    init() {}

    // 逐字段容错解码：旧版本数据缺少新字段时保留已有内容；
    // 但完全不含已知字段的 JSON（如 {"foo":"bar"}）视为无效数据，拒绝解码
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let knownKeys: [CodingKeys] = [.pet, .activeMember, .members, .entries, .reminders, .remindersEnabled, .weights, .ai, .chat]
        guard knownKeys.contains(where: { c.contains($0) }) else {
            throw DecodingError.dataCorruptedError(forKey: .pet, in: c, debugDescription: "不是同窝的数据文件")
        }
        pet = try c.decodeIfPresent(Pet.self, forKey: .pet) ?? Pet()
        activeMember = try c.decodeIfPresent(String.self, forKey: .activeMember) ?? "me"
        members = try c.decodeIfPresent([Member].self, forKey: .members) ?? [Member(id: "me", name: "我", role: "owner")]
        entries = try c.decodeIfPresent([Entry].self, forKey: .entries) ?? []
        reminders = try c.decodeIfPresent([Reminder].self, forKey: .reminders) ?? []
        remindersEnabled = try c.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? true
        weights = try c.decodeIfPresent([WeightRecord].self, forKey: .weights) ?? []
        ai = try c.decodeIfPresent(AIConfig.self, forKey: .ai) ?? AIConfig()
        chat = try c.decodeIfPresent([ChatMessage].self, forKey: .chat) ?? []
    }
}

// MARK: - 预设

let speciesOptions: [(key: String, label: String)] = [
    ("cat", "猫"), ("dog", "狗"), ("rabbit", "兔子"), ("other", "其他"),
]

let aiProviders: [(key: String, label: String, baseURL: String, model: String)] = [
    ("deepseek", "DeepSeek", "https://api.deepseek.com/v1", "deepseek-chat"),
    ("openai", "OpenAI", "https://api.openai.com/v1", "gpt-4o-mini"),
    ("glm", "智谱 GLM", "https://open.bigmodel.cn/api/paas/v4", "glm-4-flash"),
    ("qwen", "通义千问", "https://dashscope.aliyuncs.com/compatible-mode/v1", "qwen-plus"),
    ("custom", "自定义（OpenAI 兼容）", "", ""),
]

/// Pawly 的语气选项：hint 会注入系统提示词
let aiTones: [(key: String, label: String, hint: String)] = [
    ("warm", "温暖陪伴", "像家人一样自然关心，语气温和，不说教"),
    ("lively", "活泼俏皮", "轻松幽默，可以偶尔用 emoji，但不过分"),
    ("concise", "简洁利落", "直奔重点，少寒暄，先给答案"),
    ("calm", "冷静专业", "条理清晰，先结论后依据，语气平稳"),
]

// MARK: - 时间工具

let dateFormatterCN: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

func dateKey(_ d: Date = Date()) -> String { dateFormatterCN.string(from: d) }
func timeKey(_ d: Date = Date()) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: d)
}



func uid(_ prefix: String = "id") -> String {
    "\(prefix)-\(UUID().uuidString.prefix(8))-\(Int(Date().timeIntervalSince1970) % 100000)"
}

// MARK: - Store

final class Store: ObservableObject {
    static let shared = Store()
    private let key = "covey-state-v1"

    @Published var data = CoveyData() {
        didSet { save() }
    }

    /// 「让 AI 分析」等待发送的问题，由 AIChatView 消费
    var pendingAiPrompt: String?

    private init() { load() }

    private func load() {
        guard let raw = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(CoveyData.self, from: raw) else { return }
        data = decoded
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(raw, forKey: key)
        }
    }

    func reset() {
        data = CoveyData()
    }

    // MARK: 记录统计

    /// 最近 days 天的记录
    func entriesSince(days: Int) -> [Entry] {
        let since = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return data.entries.filter { $0.ts >= since }
    }

    func weekEntryCount() -> Int { entriesSince(days: 7).count }

    /// 连续记录天数：今天或昨天有记录就算起点
    func recordStreak() -> Int {
        var streak = 0
        var cursor = Date()
        let hasToday = data.entries.contains { dateKey($0.ts) == dateKey() }
        if !hasToday { cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor)! }
        while data.entries.contains(where: { dateKey($0.ts) == dateKey(cursor) }) {
            streak += 1
            cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor)!
        }
        return streak
    }

    func remindersDueSoon(days: Int = 7) -> [Reminder] {
        let limit = dateKey(Calendar.current.date(byAdding: .day, value: days, to: Date())!)
        return data.reminders.filter { !$0.done && $0.due <= limit }.sorted { $0.due < $1.due }
    }

    // MARK: 记录

    func addEntry(_ entry: Entry) {
        data.entries.insert(entry, at: 0)
        if data.entries.count > 800 { data.entries = Array(data.entries.prefix(800)) }
    }

    func deleteEntry(_ id: String) {
        data.entries.removeAll { $0.id == id }
    }

    func entriesGroupedByDay(filtered: [Entry]) -> [(String, [Entry])] {
        var map: [String: [Entry]] = [:]
        for e in filtered { map[dateKey(e.ts), default: []].append(e) }
        return map.sorted { $0.key > $1.key }
    }

    // MARK: 成员 / 档案 / 体重

    func memberName(_ id: String) -> String {
        data.members.first { $0.id == id }?.name ?? "我"
    }

    func addWeight(date: String, kg: Double) {
        data.weights.removeAll { $0.date == date }
        data.weights.append(WeightRecord(id: uid("w"), date: date, kg: kg))
        data.weights.sort { $0.date < $1.date }
        data.pet.weight = String(kg)
    }

    // MARK: AI

    func appendChat(_ msg: ChatMessage) {
        data.chat.append(msg)
        if data.chat.count > 120 { data.chat = Array(data.chat.suffix(120)) }
    }

    func resolvePendingChat(_ content: String) {
        if let idx = data.chat.lastIndex(where: { $0.pending }) {
            data.chat[idx].content = content
            data.chat[idx].pending = false
            data.chat[idx].ts = Date()
        }
    }

    // MARK: 导出 / 导入

    func exportJSON() -> Data? {
        try? JSONEncoder().encode(data)
    }

    func importJSON(_ raw: Data) -> Bool {
        guard let decoded = try? JSONDecoder().decode(CoveyData.self, from: raw) else { return false }
        data = decoded
        return true
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
