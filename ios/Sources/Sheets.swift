// 同窝 Covey · 弹窗表单（记一笔 / 提醒 / 档案 / 体重 / 成员）
import SwiftUI

private func sheetCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
        .padding(18)
        .background(CoveyTheme.bg)
        .presentationDetents([.medium])
}

// MARK: - 记一笔

struct NoteSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var type = "note"
    @State private var text = ""
    @State private var amount = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(["note", "spend", "health"], id: \.self) { t in
                        let label = EntryType(rawValue: t)?.label ?? t
                        Button { type = t } label: {
                            Text(label)
                                .font(.subheadline)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .foregroundStyle(type == t ? .white : CoveyTheme.ink2)
                                .background(type == t ? CoveyTheme.ink : CoveyTheme.card)
                                .overlay(Capsule().stroke(type == t ? CoveyTheme.ink : CoveyTheme.line))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                if type == "spend" {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("金额（元）").font(.caption).foregroundStyle(CoveyTheme.ink2)
                        TextField("0.00", text: $amount).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("内容").font(.caption).foregroundStyle(CoveyTheme.ink2)
                    TextField(type == "spend" ? "买了什么？" : type == "health" ? "疫苗、驱虫、就诊或异常情况…" : "今天发生了什么？", text: $text, axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(3...6)
                }
                Spacer()
                HStack {
                    Button("取消") { dismiss() }
                        .buttonStyle(.bordered).tint(CoveyTheme.ink2)
                    Button("保存") {
                        let amountValue = type == "spend" ? Double(amount.trimmed) : nil
                        guard !text.trimmed.isEmpty || amountValue != nil else { return }
                        store.addEntry(Entry(id: uid("e"), ts: Date(), type: EntryType(rawValue: type) ?? .note, text: text.trimmed, amount: amountValue))
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent).tint(CoveyTheme.accent)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(18)
            .background(CoveyTheme.bg)
            .navigationTitle("记一笔")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 提醒

struct ReminderSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var category = "vaccine"
    @State private var due = Date()
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("事项（例如：猫三联疫苗加强）", text: $title)
                Picker("类型", selection: $category) {
                    ForEach(ReminderCategory.allCases, id: \.self) { c in
                        Text(c.label).tag(c.rawValue)
                    }
                }
                DatePicker("日期", selection: $due, displayedComponents: .date)
                TextField("备注（可选）", text: $note)
            }
            .navigationTitle("新建提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        guard !title.trimmed.isEmpty else { return }
                        store.data.reminders.append(Reminder(id: uid("r"), title: title.trimmed, category: ReminderCategory(rawValue: category) ?? .custom, due: dateKey(due), note: note.trimmed))
                        dismiss()
                    }
                    .disabled(title.trimmed.isEmpty)
                }
            }
        }
    }
}

// MARK: - 宠物档案

struct ProfileSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var species = "cat"
    @State private var breed = ""
    @State private var birthday = Date()
    @State private var hasBirthday = false
    @State private var weight = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("名字", text: $name)
                Picker("物种", selection: $species) {
                    ForEach(speciesOptions, id: \.key) { s in
                        Text(s.label).tag(s.key)
                    }
                }
                TextField("品种（如：布偶猫）", text: $breed)
                Toggle("设置生日", isOn: $hasBirthday)
                if hasBirthday { DatePicker("生日", selection: $birthday, displayedComponents: .date) }
                TextField("当前体重（kg）", text: $weight).keyboardType(.decimalPad)
            }
            .navigationTitle("宠物档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .disabled(name.trimmed.isEmpty)
                }
            }
            .onAppear {
                let p = store.data.pet
                name = p.name
                species = p.species
                breed = p.breed
                weight = p.weight
                if let d = dateFormatterCN.date(from: p.birthday) { birthday = d; hasBirthday = true }
            }
        }
    }

    private func save() {
        let oldSpecies = store.data.pet.species
        store.data.pet.name = name.trimmed
        store.data.pet.breed = breed.trimmed
        store.data.pet.birthday = hasBirthday ? dateKey(birthday) : ""
        store.data.pet.weight = weight.trimmed
        if species != oldSpecies {
            store.setSpecies(species)
        } else {
            store.data.pet.species = species
        }
        dismiss()
    }
}

// MARK: - 体重

struct WeightSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var date = Date()
    @State private var kg = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("日期", selection: $date, displayedComponents: .date)
                TextField("体重（kg）", text: $kg).keyboardType(.decimalPad)
            }
            .navigationTitle("记录体重")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        guard let value = Double(kg.trimmed), value > 0 else { return }
                        store.addWeight(date: dateKey(date), kg: value)
                        dismiss()
                    }
                    .disabled(Double(kg.trimmed) == nil || Double(kg.trimmed) ?? 0 <= 0)
                }
            }
        }
    }
}

// MARK: - 成员

struct MemberSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var role = "caregiver"
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("名字（例如：妈妈）", text: $name)
                Picker("角色", selection: $role) {
                    Text("照护人（可以记记录）").tag("caregiver")
                    Text("围观（只看）").tag("viewer")
                }
                Text("成员只保存在本机，用来区分谁做了什么。")
                    .font(.caption).foregroundStyle(CoveyTheme.ink2)
                if !error.isEmpty { Text(error).foregroundStyle(CoveyTheme.danger).font(.caption) }
            }
            .navigationTitle("添加成员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("添加") {
                        let n = name.trimmed
                        if n.isEmpty { error = "请填写名字"; return }
                        if store.data.members.contains(where: { $0.name == n }) { error = "已有同名成员"; return }
                        store.data.members.append(Member(id: uid("m"), name: n, role: role))
                        dismiss()
                    }
                }
            }
        }
    }
}
