// 同窝 Covey · 我的页（AI 配置、数据、关于）
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MeView: View {
    @EnvironmentObject var store: Store
    @State private var provider = "deepseek"
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var testResult = ""
    @State private var testing = false
    @State private var showExport = false
    @State private var showClearConfirm = false
    @State private var importedMsg = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("我的").font(.title.bold()).frame(maxWidth: .infinity, alignment: .leading)
                    Text("AI 配置、数据与本地存储。")
                        .font(.subheadline).foregroundStyle(CoveyTheme.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    aiCard
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
    }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI 助手设置").font(.headline)

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
        .padding(14)
        .background(CoveyTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(CoveyTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func saveConfig() {
        store.data.ai = AIConfig(provider: provider, baseURL: baseURL.trimmed, apiKey: apiKey.trimmed, model: model.trimmed)
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("数据").font(.headline).padding(.bottom, 4)
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
        }
        .padding(14)
        .background(CoveyTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(CoveyTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("关于").font(.headline)
            Text("同窝 Covey · 本地优先的宠物日常。所有数据保存在这台设备中，AI 功能需要你在上方配置自己的 API。")
                .font(.caption).foregroundStyle(CoveyTheme.ink2)
        }
        .padding(14)
        .background(CoveyTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(CoveyTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 18))
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
        // 用文件选择器导入 JSON
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
                Text("包含宠物档案、照护记录、手账、提醒、体重和 AI 聊天记录。")
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
