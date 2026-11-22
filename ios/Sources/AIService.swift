// 同窝 Covey · Pawly AI 服务（OpenAI 兼容 chat/completions）
import Foundation

enum AIError: Error {
    case notConfigured
    case requestFailed(String)
}

struct AIService {
    let config: AIConfig

    private func chatURL() throws -> URL {
        let base = config.baseURL.trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/chat/completions") else { throw AIError.requestFailed("API 地址无效") }
        return url
    }

    private func request(messages: [[String: String]], maxTokens: Int? = nil) throws -> URLRequest {
        var req = URLRequest(url: try chatURL())
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(config.apiKey.trimmed)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = ["model": config.model.isEmpty ? "gpt-4o-mini" : config.model, "messages": messages]
        if let maxTokens { body["max_tokens"] = maxTokens }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60
        return req
    }

    /// 发一条最小请求验证配置可用
    func testConnection() async -> Result<String, AIError> {
        guard config.configured else { return .failure(.notConfigured) }
        do {
            let req = try request(messages: [["role": "user", "content": "只回复两个字：正常"]], maxTokens: 16)
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let text = String(data: data, encoding: .utf8) ?? ""
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                return .failure(.requestFailed("请求失败（\(code)）\(text.prefix(120))"))
            }
            return .success("连接成功 · \(config.model.isEmpty ? "默认模型" : config.model)")
        } catch let err as AIError {
            return .failure(err)
        } catch {
            return .failure(.requestFailed("网络错误：\(error.localizedDescription)"))
        }
    }

    /// 发送对话，返回 Pawly 的回复文本
    func send(systemPrompt: String, history: [[String: String]]) async -> Result<String, AIError> {
        guard config.configured else { return .failure(.notConfigured) }
        var messages = [["role": "system", "content": systemPrompt]]
        messages.append(contentsOf: history)
        do {
            let req = try request(messages: messages)
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let text = String(data: data, encoding: .utf8) ?? ""
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                return .failure(.requestFailed("AI 请求失败（\(code)）\(text.prefix(200))"))
            }
            let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let content = (((decoded?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String) ?? ""
            guard !content.isEmpty else { return .failure(.requestFailed("AI 返回为空")) }
            return .success(content)
        } catch let err as AIError {
            return .failure(err)
        } catch {
            return .failure(.requestFailed("网络错误：\(error.localizedDescription)"))
        }
    }
}

/// 注入宠物档案 + 近 14 天照护 + 最近记录 + 体重 + 提醒的系统提示词
func buildSystemPrompt(from store: Store) -> String {
    let d = store.data
    let speciesLabel = speciesOptions.first { $0.key == d.pet.species }?.label ?? d.pet.species
    var lines: [String] = [
        "你是「同窝 Covey」里的宠物照护助手，名字叫 Pawly。你陪伴用户照顾家里的宠物。",
        "说话用简体中文，语气温暖、简洁、像懂宠物的朋友。回答控制在 150 字以内，除非用户要求详细。",
        "建议要有依据（引用记录或常识），并说明不确定的地方；最终决定权在用户，不要替用户做医疗诊断，涉及生病就建议就医。",
        "",
        "宠物档案：名字「\(d.pet.name)」，物种：\(speciesLabel)\(d.pet.breed.isEmpty ? "" : "，品种：" + d.pet.breed)\(d.pet.birthday.isEmpty ? "" : "，生日：" + d.pet.birthday)\(d.pet.weight.isEmpty ? "，体重未知" : "，体重：" + d.pet.weight + "kg")。",
    ]

    var stats: [String] = []
    for i in stride(from: 13, through: 0, by: -1) {
        let day = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
        let key = dateKey(day)
        let comp = d.completions[key] ?? [:]
        let doneTasks = d.tasks.filter { comp[$0.id] != nil }
        let shortKey = key.dropFirst(5)
        stats.append("\(shortKey)：\(doneTasks.count)/\(d.tasks.count)（\(doneTasks.map(\.title).joined(separator: "、").isEmpty ? "无" : doneTasks.map(\.title).joined(separator: "、"))）")
    }
    lines.append(contentsOf: ["", "近 14 天照护记录："] + stats)

    let recent = d.entries.prefix(15).map { e -> String in
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        let time = f.string(from: e.ts)
        let kind = e.type.label
        let extra = e.amount.map { " ¥\($0)" } ?? ""
        return "- \(time) [\(kind)] \(e.text.isEmpty ? "（无文字）" : e.text)\(extra)"
    }
    lines.append("")
    if recent.isEmpty {
        lines.append("最近还没有记录。")
    } else {
        lines.append("最近记录：")
        lines.append(contentsOf: recent)
    }

    if !d.weights.isEmpty {
        let w = d.weights.suffix(5).map { "\($0.date): \($0.kg)kg" }
        lines.append("")
        lines.append("体重记录（近几次）：\(w.joined(separator: "；"))")
    }

    let reminders = d.reminders.filter { !$0.done }.prefix(8).map { "- \($0.due) \($0.category.label)：\($0.title)" }
    if !reminders.isEmpty {
        lines.append("")
        lines.append("待办提醒：")
        lines.append(contentsOf: reminders)
    }

    lines.append("")
    lines.append("请基于以上真实记录回答。")
    return lines.joined(separator: "\n")
}
