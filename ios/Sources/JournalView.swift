// 同窝 Covey · 记录手账页
import SwiftUI

struct JournalView: View {
    @EnvironmentObject var store: Store
    @State private var filter = "all"
    @State private var query = ""

    private var filtered: [Entry] {
        var list = store.data.entries
        if filter != "all" { list = list.filter { $0.type.rawValue == filter } }
        if !query.trimmed.isEmpty {
            let q = query.trimmed.lowercased()
            list = list.filter { $0.text.lowercased().contains(q) }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("记录手账").font(.title.bold())
                    Text("照护、照片、花费和健康，都按时间存好。")
                        .font(.subheadline).foregroundStyle(CoveyTheme.ink2)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(CoveyTheme.ink3)
                        TextField("搜索记录内容", text: $query)
                    }
                    .padding(12)
                    .background(CoveyTheme.card)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(CoveyTheme.line))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    filterRow

                    if filtered.isEmpty {
                        Text(query.trimmed.isEmpty ? "这个分类还没有记录" : "没有匹配的记录")
                            .font(.subheadline).foregroundStyle(CoveyTheme.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                    } else {
                        ForEach(store.entriesGroupedByDay(filtered: filtered), id: \.0) { day, entries in
                            Text(dayLabel(day))
                                .font(.caption.bold())
                                .foregroundStyle(CoveyTheme.ink3)
                                .padding(.top, 6)
                            ForEach(entries) { entry in
                                EntryRow(entry: entry)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(CoveyTheme.bg)
            .navigationBarHidden(true)
        }
    }

    private var filterRow: some View {
        let items: [(String, String)] = [
            ("all", "全部"), ("photo", "照片"), ("spend", "花费"),
            ("health", "健康"), ("note", "日常"),
        ]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.0) { key, label in
                    Button {
                        filter = key
                    } label: {
                        Text(label)
                            .font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .foregroundStyle(filter == key ? .white : CoveyTheme.ink2)
                            .background(filter == key ? CoveyTheme.ink : CoveyTheme.card)
                            .overlay(Capsule().stroke(filter == key ? CoveyTheme.ink : CoveyTheme.line))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func dayLabel(_ key: String) -> String {
        let today = dateKey()
        if key == today { return "今天" }
        let yesterday = dateKey(Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        if key == yesterday { return "昨天" }
        guard let d = dateFormatterCN.date(from: key) else { return key }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEE"
        return f.string(from: d)
    }
}
