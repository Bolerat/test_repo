// 同窝 Covey · 设置页（AI 配置、提醒、宠物与亲友、数据与隐私）
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MeView: View {
    @EnvironmentObject var store: Store
    @State private var provider = "deepseek"
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var tone = "warm"
    @State private var testResult = ""
    @State private var testing = false
    @State private var showExport = false
    @State private var showClearConfirm = false
    @State private var showMemory = false
    @State private var importedMsg = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("设置").font(.title.bold()).frame(maxWidth: .infinity, alignment: .leading)
                    Text("AI 助手、提醒、数据与本地存储。")
                        .font(.subheadline).foregroundStyle(CoveyTheme.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    aiCard
                    remindCard
                    groupCard
                    memoryRow
                    dataCard
                    aboutCard
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(CoveyTheme.bg)
            .navigationBarHidden(true)
            .onAppear { syncFromStore() }
            .sheet(isPresented: $showExport) { ExportSheet().environmentObject(store) }
            .sheet(isPresented: $showMemory) { PawlyMemorySheet().environmentObject(store) }
            .confirmationDialog("清空所有数据？此操作不可恢复。", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("清空", role: .destructive) { store.reset() }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private func syncFromStore() {
        provider = store.data.ai.provider
        baseURL = store.data.ai.baseURL
        apiKey = store.data.ai.apiKey
        model = store.data.ai.model
        tone = store.data.ai.tone
    }

    // MARK: - AI 助手

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI 助手").font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("服务商").font(.caption).foregroundStyle(CoveyTheme.ink2)
                Picker("服务商", selection: $provider) {
                    ForEach(aiProviders, id: \.key) { p in
                        Text(p.label).tag(p.key)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: provider) { _, key in
                    if let preset = aiProviders.first(where: { $0.key == key }), key != "custom" {
                        baseURL = preset.baseURL
                        model = preset.model
                    }
                }
            }

            field("API 地址（OpenAI 兼容）", $baseURL, "https://api.example.com/v1")
            VStack(alignment: .leading, spacing: 4) {
                Text("API Key").font(.caption).foregroundStyle(CoveyTheme.ink2)
                SecureField("sk-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }
            field("模型", $model, "gpt-4o-mini")

            VStack(alignment: .leading, spacing: 4) {
                Text("AI 语气").font(.caption).foregroundStyle(CoveyTheme.ink2)
                Picker("AI 语气", selection: $tone) {
                    ForEach(aiTones, id: \.key) { t in
                        Text(t.label).tag(t.key)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("配置只保存在本机。若接口不支持跨域访问（原生 App 不受浏览器 CORS 限制），请确认地址可达。")
                .font(.caption2).foregroundStyle(CoveyTheme.ink2)

            HStack(spacing: 10) {
                Button {
                    saveConfig()
                    testing = true
                    testResult = "测试中…"
                    Task {
                        let res = await AIService(config: store.data.ai).testConnection()
                        await MainActor.run {
                            switch res {
                            case .success(let m): testResult = m
                            case .failure(let e):
                                switch e {
                                case .notConfigured: testResult = "请先填写地址和 Key"
                                case .requestFailed(let m): testResult = m
                                }
                            }
                            testing = false
                        }
                    }
                } label: {
                    Text(testing ? "测试中…" : "测试连接")
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(CoveyTheme.card)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CoveyTheme.line))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain).foregroundStyle(CoveyTheme.ink).disabled(testing)

                Button {
                    saveConfig()
                    testResult = "已保存"
                } label: {
                    Text("保存")
                        .font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(CoveyTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            if !testResult.isEmpty {
                Text(testResult)
                    .font(.caption)
                    .foregroundStyle(testResult.contains("成功") || testResult.contains("已保存") ? CoveyTheme.sage : CoveyTheme.danger)
            }
        }
        .modifier(CardStyle())
    }

    private func saveConfig() {
        var config = AIConfig()
        config.provider = provider
        config.baseURL = baseURL.trimmed
        config.apiKey = apiKey.trimmed
        config.model = model.trimmed
        config.tone = tone
        store.data.ai = config
    }

    // MARK: - 提醒

    private var remindCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("提醒").font(.headline)
            Toggle("Pawly 提醒", isOn: Binding(
                get: { store.data.remindersEnabled },
                set: { store.data.remindersEnabled = $0 }
            ))
            .tint(CoveyTheme.accent)
            Text("开启后，「今日」页会显示 7 天内到期的提醒；关闭后只保留提醒记录本身。")
                .font(.caption2).foregroundStyle(CoveyTheme.ink2)
        }
        .modifier(CardStyle())
    }

    // MARK: - 宠物与亲友

    private var groupCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("宠物与亲友").font(.headline).padding(.bottom, 4)
            groupRow("宠物档案", "\(store.data.pet.name) · \(speciesLabel)") {
                goPetTab()
            }
            Divider()
            groupRow("家庭成员", "\(store.data.members.count) 位成员，本机保存") {
                goPetTab()
            }
        }
        .modifier(CardStyle())
    }

    private func groupRow(_ title: String, _ sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline).foregroundStyle(CoveyTheme.ink)
                    Text(sub).font(.caption2).foregroundStyle(CoveyTheme.ink2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(CoveyTheme.ink3)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func goPetTab() {
        NotificationCenter.default.post(name: .switchTab, object: 3)
    }

    private var speciesLabel: String {
        speciesOptions.first { $0.key == store.data.pet.species }?.label ?? "其他"
    }

    // MARK: - Pawly 的记忆

    private var memoryRow: some View {
        Button { showMemory = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pawly 的记忆").font(.subheadline).foregroundStyle(CoveyTheme.ink)
                    Text("查看 AI 回答时读取哪些资料")
                        .font(.caption2).foregroundStyle(CoveyTheme.ink2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(CoveyTheme.ink3)
            }
            .padding(14)
            .background(CoveyTheme.card)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(CoveyTheme.line))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 数据与隐私

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("数据与隐私").font(.headline).padding(.bottom, 4)
            dataRow("导出数据", "下载全部记录为 JSON 文件") {
                showExport = true
            }
            Divider()
            dataRow("导入数据", "从 JSON 文件恢复（覆盖当前数据）") {
                importFromFile()
            }
            if !importedMsg.isEmpty {
                Text(importedMsg).font(.caption2).foregroundStyle(CoveyTheme.ink2).padding(.top, 4)
            }
            Divider()
            dataRow("清空数据", "删除本机全部记录，不可恢复", danger: true) {
                showClearConfirm = true
            }
            Text("所有数据只保存在这台设备上；照片会自动压缩后存储。AI 功能只在你配置 API 后启用。")
                .font(.caption2).foregroundStyle(CoveyTheme.ink2)
                .padding(.top, 8)
        }
        .modifier(CardStyle())
    }

    // MARK: - 关于

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("关于").font(.headline)
            Text("同窝 Covey · 围绕你和宠物的日常。记录、照片、提醒和 AI 建议都以宠物为中心。")
                .font(.caption).foregroundStyle(CoveyTheme.ink2)
        }
        .modifier(CardStyle())
    }

    private func field(_ label: String, _ binding: Binding<String>, _ placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(CoveyTheme.ink2)
            TextField(placeholder, text: binding)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
    }

    private func dataRow(_ title: String, _ sub: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).foregroundStyle(danger ? CoveyTheme.danger : CoveyTheme.ink)
                Text(sub).font(.caption2).foregroundStyle(CoveyTheme.ink2)
            }
            Spacer()
            Button(title.replacing("数据", with: ""), action: action)
                .font(.caption)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(danger ? CoveyTheme.accentSoft : CoveyTheme.card)
                .overlay(Capsule().stroke(danger ? CoveyTheme.accentSoft : CoveyTheme.line))
                .clipShape(Capsule())
                .foregroundStyle(danger ? CoveyTheme.danger : CoveyTheme.ink)
        }
        .padding(.vertical, 8)
    }

    private func importFromFile() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        let delegate = ImportDelegate { url in
            guard let url, let data = try? Data(contentsOf: url) else { importedMsg = "读取失败"; return }
            importedMsg = store.importJSON(data) ? "导入成功" : "文件格式不正确"
        }
        picker.delegate = delegate
        retainedDelegates.append(delegate)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(picker, animated: true)
        }
    }
}

private struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(CoveyTheme.card)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(CoveyTheme.line))
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Pawly 的记忆

struct PawlyMemorySheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private var speciesLabel: String {
        speciesOptions.first { $0.key == store.data.pet.species }?.label ?? "其他"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pawly 回答时会读取") {
                    Text("宠物档案：\(store.data.pet.name)（\(speciesLabel)）")
                    Text("最近 \(min(store.data.entries.count, 15)) 条记录")
                    Text("近 14 天每天的记录数量")
                    if let last = store.data.weights.last {
                        Text("体重：最近 \(last.kg) kg（\(last.date)）")
                    } else {
                        Text("体重：暂无记录")
                    }
                    Text("提醒：\(store.data.remindersEnabled ? "\(store.remindersDueSoon().count) 件待办" : "已关闭")")
                    Text("AI 对话：最近 20 条")
                }
                Section("说明") {
                    Text("这些资料只在你配置了 API 后发送给对应的 AI 服务，用于生成回答；不配置时 Pawly 只使用本机规则给出观察。你可以随时更换或清除 API 配置。")
                        .font(.caption)
                        .foregroundStyle(CoveyTheme.ink2)
                }
            }
            .navigationTitle("Pawly 的记忆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } }
            }
        }
    }
}

// MARK: - 导出 sheet（保存 JSON 到文件 / 分享）

struct ExportSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var savedTo: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.down").font(.largeTitle).foregroundStyle(CoveyTheme.accent)
                Text("导出全部数据").font(.headline)
                Text("包含宠物档案、记录、提醒、体重和 AI 对话历史。")
                    .font(.caption).foregroundStyle(CoveyTheme.ink2).multilineTextAlignment(.center)
                if !savedTo.isEmpty {
                    Text(savedTo).font(.caption).foregroundStyle(CoveyTheme.sage)
                }
                Button {
                    guard let data = store.exportJSON() else { savedTo = "导出失败"; return }
                    let filename = "covey-backup-\(dateKey()).json"
                    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
                    do {
                        try data.write(to: url)
                        savedTo = "已保存到 App 文档目录：\(filename)"
                    } catch {
                        savedTo = "写入失败：\(error.localizedDescription)"
                    }
                } label: {
                    Text("保存到文件")
                        .font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(CoveyTheme.accent).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .navigationTitle("导出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } }
            }
        }
    }
}

// MARK: - 文件导入 delegate

private var retainedDelegates: [ImportDelegate] = []

private class ImportDelegate: NSObject, UIDocumentPickerDelegate {
    let onPick: (URL?) -> Void
    init(onPick: @escaping (URL?) -> Void) { self.onPick = onPick }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        onPick(urls.first)
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onPick(nil) }
}
