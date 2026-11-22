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

struct CareTask: Codable, Identifiable {
    var id: String
    var title: String
    var type: String      // feeding | water | clean | walk | companion
    var time: String      // HH:mm
}

struct TaskCompletion: Codable {
    var by: String
    var at: Date
}

enum EntryType: String, Codable {
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
    var configured: Bool { !apiKey.trimmed.isEmpty && !baseURL.trimmed.isEmpty }
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
    var tasks: [CareTask] = []
    var completions: [String: [String: TaskCompletion]] = [:]
    var entries: [Entry] = []
    var reminders: [Reminder] = []
    var weights: [WeightRecord] = []
    var ai = AIConfig()
    var chat: [ChatMessage] = []
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

func defaultTasks(for species: String) -> [CareTask] {
    let base = [
        CareTask(id: "breakfast", title: "早餐", type: "feeding", time: "07:30"),
        CareTask(id: "water", title: "换水", type: "water", time: "12:00"),
        CareTask(id: "dinner", title: "晚餐", type: "feeding", time: "18:30"),
    ]
    switch species {
    case "dog": return base + [CareTask(id: "walk", title: "遛弯", type: "walk", time: "20:00")]
    case "cat": return base + [CareTask(id: "litter", title: "清理猫砂", type: "clean", time: "20:00")]
    default: return base + [CareTask(id: "play", title: "陪伴玩耍", type: "companion", time: "20:00")]
    }
}

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
              let decoded = try? JSONDecoder().decode(CoveyData.self, from: raw) else {
            data.tasks = defaultTasks(for: data.pet.species)
            return
        }
        data = decoded
        if data.tasks.isEmpty { data.tasks = defaultTasks(for: data.pet.species) }
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(raw, forKey: key)
        }
    }

    func reset() {
        data = CoveyData()
        data.tasks = defaultTasks(for: data.pet.species)
    }

    // MARK: 照护任务

    func isTaskDone(_ id: String, on day: String = dateKey()) -> Bool {
        data.completions[day]?[id] != nil
    }

    func toggleTask(_ id: String) {
        if isTaskDone(id) { undoTask(id) } else { completeTask(id) }
    }

    func completeTask(_ id: String) {
        let day = dateKey()
        var dayMap = data.completions[day] ?? [:]
        guard dayMap[id] == nil else { return }
        dayMap[id] = TaskCompletion(by: data.activeMember, at: Date())
        data.completions[day] = dayMap
        if let task = data.tasks.first(where: { $0.id == id }) {
            data.entries.insert(Entry(id: uid("e"), ts: Date(), type: .care, text: task.title, taskId: id), at: 0)
        }
    }

    func undoTask(_ id: String) {
        let day = dateKey()
        data.completions[day]?.removeValue(forKey: id)
        data.entries.removeAll { $0.type == .care && $0.taskId == id && dateKey($0.ts) == day }
    }

    func careProgress() -> (done: Int, total: Int) {
        (data.tasks.filter { isTaskDone($0.id) }.count, data.tasks.count)
    }

    func careStreak() -> Int {
        var streak = 0
        var cursor = Date()
        let allDoneToday = data.tasks.allSatisfy { isTaskDone($0.id) }
        if !allDoneToday { cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor)! }
        while true {
            let key = dateKey(cursor)
            guard data.tasks.allSatisfy({ isTaskDone($0.id, on: key) }) else { break }
            streak += 1
            cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor)!
        }
        return streak
    }

    func weekStats() -> (done: Int, total: Int, rate: Int) {
        var done = 0
        for i in stride(from: 6, through: 0, by: -1) {
            let d = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let key = dateKey(d)
            let comp = data.completions[key] ?? [:]
            done += data.tasks.filter { comp[$0.id] != nil }.count
        }
        let total = data.tasks.count * 7
        return (done, total, total == 0 ? 0 : Int(round(Double(done) / Double(total) * 100)))
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

    func setSpecies(_ species: String) {
        data.pet.species = species
        data.tasks = defaultTasks(for: species)
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
        if data.tasks.isEmpty { data.tasks = defaultTasks(for: data.pet.species) }
        return true
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
