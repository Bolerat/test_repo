// 同窝 Covey · AI 助手页（Pawly）
import SwiftUI

struct AIChatView: View {
    @EnvironmentObject var store: Store
    @State private var input = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            if !store.data.ai.configured {
                unconfigured
            } else {
                configured
            }
        }
        .onAppear { consumePendingPrompt() }
    }

    private var unconfigured: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("AI 助手 Pawly").font(.title.bold())
                Text("结合宠物档案和照护记录，给出有依据的建议。")
                    .font(.subheadline).foregroundStyle(CoveyTheme.ink2)

                VStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .font(.largeTitle).foregroundStyle(CoveyTheme.accent)
                    Text("还没有配置 AI").font(.headline)
                    Text("在「我的 → AI 助手设置」中填入 API 地址、Key 和模型即可使用。")
                        .font(.caption).foregroundStyle(CoveyTheme.ink2).multilineTextAlignment(.center)
                    NavigationLink(destination: MeView()) {
                        Text("去设置")
                            .font(.subheadline.bold()).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(CoveyTheme.accent).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(CoveyTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(CoveyTheme.line))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                ruleInsightCard
            }
            .padding(16)
        }
        .background(CoveyTheme.bg)
        .navigationBarHidden(true)
    }

    private var configured: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("AI 助手 Pawly").font(.title.bold())
                    Text("基于真实记录回答，建议仅供参考。")
                        .font(.subheadline).foregroundStyle(CoveyTheme.ink2)
                    quickChips
                    if store.data.chat.isEmpty {
                        bubble(role: "assistant", text: "你好，我是 Pawly。问我关于\(store.data.pet.name)的照护、记录或安排都可以。", ts: nil)
                    }
                    ForEach(store.data.chat) { msg in
                        bubble(role: msg.role, text: msg.content, ts: msg.ts, pending: msg.pending)
                    }
                }
                .padding(16)
            }
            .background(CoveyTheme.bg)

            Divider()
            HStack(spacing: 8) {
                TextField("问点什么…", text: $input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                Button {
                    let text = input.trimmed
                    guard !text.isEmpty else { return }
                    input = ""
                    send(text)
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                }
                .disabled(busy || input.trimmed.isEmpty)
                .foregroundStyle(CoveyTheme.accent)
            }
            .padding(10)
            .background(.bar)
        }
    }

    private var quickChips: some View {
        let items = [
            "总结我家宠物最近一周的状态",
            "根据记录，给我几点照护上的建议",
            "这周有哪些照护环节容易被忽略？",
        ]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { q in
                    Button { send(q) } label: {
                        Text(q)
                            .font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .foregroundStyle(CoveyTheme.ink2)
                            .background(CoveyTheme.card)
                            .overlay(Capsule().stroke(CoveyTheme.line))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func bubble(role: String, text: String, ts: Date?, pending: Bool = false) -> some View {
        HStack {
            if role == "user" { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.subheadline)
                    .italic(pending)
                    .foregroundStyle(pending ? CoveyTheme.ink3 : (role == "user" ? .white : CoveyTheme.ink))
                Text("\(role == "user" ? "我" : "Pawly")\(ts.map { " · " + fmtChat($0) } ?? "")")
                    .font(.caption2)
                    .foregroundStyle(role == "user" ? .white.opacity(0.6) : CoveyTheme.ink3)
            }
            .padding(12)
            .background(role == "user" ? CoveyTheme.ink : CoveyTheme.card)
            .overlay(role == "user" ? nil : RoundedRectangle(cornerRadius: 16).stroke(CoveyTheme.line))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            if role != "user" { Spacer(minLength: 40) }
        }
    }

    private func fmtChat(_ ts: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: ts)
    }

    private var ruleInsightCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("不用 AI 也能看到").font(.headline)
            Text(insightText()).font(.caption).foregroundStyle(CoveyTheme.ink2)
        }
        .padding(14)
        .background(CoveyTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(CoveyTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func insightText() -> String {
        var parts: [String] = []
        let week = store.weekEntryCount()
        if week > 0 { parts.append("这周记了 \(week) 条日常。") }
        if store.data.remindersEnabled && store.remindersDueSoon().count > 0 {
            parts.append("\(store.remindersDueSoon().count) 件提醒在 7 天内到期。")
        }
        return parts.isEmpty ? "记录越多，洞察越准确。" : parts.joined()
    }

    private func consumePendingPrompt() {
        if let p = store.pendingAiPrompt {
            store.pendingAiPrompt = nil
            send(p)
        }
    }

    private func send(_ text: String) {
        let content = text.trimmed
        guard !content.isEmpty, !busy else { return }
        if !store.data.ai.configured { return }
        busy = true
        store.appendChat(ChatMessage(id: uid("c"), role: "user", content: content, ts: Date()))
        store.appendChat(ChatMessage(id: uid("c"), role: "assistant", content: "…", ts: Date(), pending: true))

        let history = store.data.chat.filter { !$0.pending }.suffix(20).map { ["role": $0.role, "content": $0.content] }
        let system = buildSystemPrompt(from: store)
        let service = AIService(config: store.data.ai)

        Task {
            let result = await service.send(systemPrompt: system, history: history)
            await MainActor.run {
                switch result {
                case .success(let reply):
                    store.resolvePendingChat(reply)
                case .failure(let err):
                    let msg: String
                    switch err {
                    case .notConfigured: msg = "AI 尚未配置"
                    case .requestFailed(let m): msg = "请求出错了：\(m)\n\n请检查「我的 → AI 助手设置」。"
                    }
                    store.resolvePendingChat(msg)
                }
                busy = false
            }
        }
    }
}
