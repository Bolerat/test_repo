// 同窝 Covey · 今日页
import SwiftUI
import PhotosUI

struct TodayView: View {
    @EnvironmentObject var store: Store
    @State private var showNoteSheet = false
    @State private var showReminderSheet = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var pendingPhoto: UIImage?
    @State private var showPhotoNote = false
    @State private var photoNote = ""
    @State private var pendingPrompt: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    hero
                    quickRow
                    if store.data.remindersEnabled { reminderCard }
                    pawlyCard
                    recentSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(CoveyTheme.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "pawprint.fill").foregroundStyle(CoveyTheme.accent)
                        Text("同窝").fontWeight(.bold)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: PetView()) {
                        petChip
                    }
                }
            }
            .sheet(isPresented: $showNoteSheet) { NoteSheet().environmentObject(store) }
            .sheet(isPresented: $showReminderSheet) { ReminderSheet().environmentObject(store) }
            .sheet(isPresented: $showPhotoNote) { photoNoteSheet }
            .onChange(of: photoSelection) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let img = UIImage(data: data) else { return }
                    await MainActor.run {
                        pendingPhoto = img
                        showPhotoNote = true
                    }
                }
            }
        }
    }

    private var hero: some View {
        let pet = store.data.pet
        let todayCount = store.data.entries.filter { dateKey($0.ts) == dateKey() }.count
        let weight = store.data.weights.last.map { formatKg($0.kg) } ?? (pet.weight.isEmpty ? nil : pet.weight)
        return VStack(spacing: 16) {
            HStack(spacing: 16) {
                petAvatar(count: todayCount)
                VStack(alignment: .leading, spacing: 8) {
                    Text(pet.name)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(CoveyTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    HStack(spacing: 6) {
                        ForEach(petTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(CoveyTheme.ink2)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(.white.opacity(0.75))
                                .clipShape(Capsule())
                        }
                    }
                    Label(weekdayCN(Date()), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(CoveyTheme.ink3)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 0) {
                heroStat(symbol: "flame.fill", color: CoveyTheme.accent, value: "\(store.recordStreak())", unit: "天", label: "连续记录")
                heroDivider
                heroStat(symbol: "book.closed.fill", color: CoveyTheme.sage, value: "\(store.weekEntryCount())", unit: "条", label: "近 7 天记录")
                heroDivider
                heroStat(symbol: "scalemass.fill", color: CoveyTheme.blue, value: weight ?? "—", unit: weight == nil ? "" : "kg", label: "体重")
            }
            .padding(.vertical, 12)
            .background(.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(16)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.top, 8)
    }

    private var heroBackground: some View {
        ZStack {
            LinearGradient(colors: [CoveyTheme.accentSoft, CoveyTheme.goldSoft], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "pawprint.fill")
                .font(.system(size: 120))
                .foregroundStyle(.white.opacity(0.45))
                .rotationEffect(.degrees(-24))
                .offset(x: 130, y: -50)
            Image(systemName: "pawprint.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.4))
                .rotationEffect(.degrees(18))
                .offset(x: 60, y: 10)
        }
    }

    /// 头像进度环：今天记满 3 条算一个完整的日常节奏
    private func petAvatar(count: Int) -> some View {
        let goal = 3
        let ratio = min(CGFloat(count) / CGFloat(goal), 1)
        let full = count >= goal
        return ZStack {
            Circle().fill(.white)
            Image(systemName: speciesSymbol)
                .font(.system(size: 36))
                .foregroundStyle(CoveyTheme.accent)
            Circle().stroke(.white.opacity(0.7), lineWidth: 6).padding(-6)
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(full ? CoveyTheme.sage : CoveyTheme.accent,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(-6)
                .animation(.easeOut(duration: 0.4), value: ratio)
        }
        .frame(width: 76, height: 76)
        .padding(6)
        .overlay(alignment: .bottom) {
            HStack(spacing: 3) {
                Image(systemName: full ? "checkmark" : "note.text")
                Text("\(count)")
            }
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(full ? CoveyTheme.sage : CoveyTheme.accent)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: 2))
            .offset(y: 8)
        }
    }

    private func heroStat(symbol: String, color: Color, value: String, unit: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Image(systemName: symbol).font(.caption).foregroundStyle(color)
                Text(value).font(.system(.title3, design: .rounded).bold()).foregroundStyle(CoveyTheme.ink)
                if !unit.isEmpty { Text(unit).font(.caption2.bold()).foregroundStyle(CoveyTheme.ink2) }
            }
            Text(label).font(.caption2).foregroundStyle(CoveyTheme.ink3)
        }
        .frame(maxWidth: .infinity)
    }

    private var heroDivider: some View {
        Rectangle().fill(CoveyTheme.line).frame(width: 1, height: 28)
    }

    private var speciesSymbol: String {
        switch store.data.pet.species {
        case "cat": return "cat.fill"
        case "dog": return "dog.fill"
        case "rabbit": return "hare.fill"
        default: return "pawprint.fill"
        }
    }

    private var petTags: [String] {
        let pet = store.data.pet
        var tags: [String] = []
        if let label = speciesOptions.first(where: { $0.key == pet.species })?.label { tags.append(label) }
        if !pet.breed.isEmpty { tags.append(pet.breed) }
        if let birth = dateFormatterCN.date(from: pet.birthday) {
            let age = Calendar.current.dateComponents([.year, .month], from: birth, to: Date())
            if let y = age.year, y > 0 { tags.append("\(y) 岁") }
            else if let m = age.month, m >= 0 { tags.append("\(max(m, 1)) 个月") }
        }
        return tags
    }

    private func formatKg(_ kg: Double) -> String {
        kg == kg.rounded() ? String(Int(kg)) : String(format: "%.1f", kg)
    }

    private var petChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(CoveyTheme.accent)
                .frame(width: 22, height: 22)
                .overlay(Text(String(store.data.pet.name.prefix(1))).font(.caption2.bold()).foregroundStyle(.white))
            Text(store.data.pet.name).font(.caption)
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(CoveyTheme.ink3)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(CoveyTheme.card)
        .overlay(Capsule().stroke(CoveyTheme.line))
        .clipShape(Capsule())
    }

    private var quickRow: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $photoSelection, matching: .images, photoLibrary: .shared()) {
                quickBtn(system: "camera.fill", title: "拍一张", color: CoveyTheme.accent)
            }
            Button { showNoteSheet = true } label: {
                quickBtn(system: "note.text", title: "记一笔", color: CoveyTheme.sage)
            }
            Button {
                let prompt = "请根据我家宠物\(store.data.pet.name)最近的记录和待办提醒，给我 3 条简短、可执行的建议。"
                NotificationCenter.default.post(name: .askAI, object: prompt)
            } label: {
                quickBtn(system: "wand.and.stars", title: "AI 建议", color: CoveyTheme.gold)
            }
        }
    }

    private func quickBtn(system: String, title: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: system).font(.title2).foregroundStyle(color)
            Text(title).font(.subheadline).foregroundStyle(CoveyTheme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(CoveyTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(CoveyTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var reminderCard: some View {
        let list = store.remindersDueSoon()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("提醒").font(.headline)
                Spacer()
                Button("+ 新建") { showReminderSheet = true }
                    .font(.caption).foregroundStyle(CoveyTheme.accent)
            }
            if list.isEmpty {
                Text("近期没有待办提醒，疫苗、驱虫、洗护都可以记在这里")
                    .font(.caption).foregroundStyle(CoveyTheme.ink2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
            ForEach(list.prefix(3)) { r in
                let overdue = r.due < dateKey()
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.title).font(.subheadline.weight(.semibold))
                        Text("\(r.category.label)\(r.note.isEmpty ? "" : " · " + r.note)")
                            .font(.caption).foregroundStyle(CoveyTheme.ink2)
                    }
                    Spacer()
                    Text(overdue ? "已过期" : r.due == dateKey() ? "今天" : "\(r.due.dropFirst(5))".replacing("-", with: "月") + "日")
                        .font(.caption.bold()).foregroundStyle(CoveyTheme.accent)
                    Button { markReminderDone(r.id) } label: {
                        Image(systemName: "checkmark.circle").foregroundStyle(CoveyTheme.sage)
                    }
                    .buttonStyle(.plain)
                    Button { store.data.reminders.removeAll { $0.id == r.id } } label: {
                        Image(systemName: "trash").foregroundStyle(CoveyTheme.ink3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(overdue ? Color(hex: 0xFDF1EE) : CoveyTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(overdue ? Color(hex: 0xF0C4BC) : CoveyTheme.line))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(14)
        .background(CoveyTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(CoveyTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var pawlyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pawly 的观察").font(.headline)
                Spacer()
                Button { NotificationCenter.default.post(name: .askAI, object: "请根据我家宠物\(store.data.pet.name)最近的记录和待办提醒，给我 3 条简短、可执行的建议。") } label: {
                    Label("让 AI 分析", systemImage: "wand.and.stars")
                        .font(.caption).foregroundStyle(CoveyTheme.accent)
                }
            }
            Text(ruleInsight()).font(.caption).foregroundStyle(CoveyTheme.ink2)
        }
        .padding(14)
        .background(CoveyTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(CoveyTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func ruleInsight() -> String {
        var parts: [String] = []
        let weekCount = store.weekEntryCount()
        if weekCount > 0 { parts.append("这周记了 \(weekCount) 条日常。") }
        if store.data.remindersEnabled {
            let due = store.remindersDueSoon().count
            if due > 0 { parts.append("\(due) 件提醒在 7 天内到期。") }
        }
        if let lastW = store.data.weights.last {
            let days = Calendar.current.dateComponents([.day], from: dateFormatterCN.date(from: lastW.date) ?? Date(), to: Date()).day ?? 0
            if days > 30 { parts.append("体重已经 \(days) 天没记录了。") }
        } else {
            parts.append("还没有体重记录，记一次可以留意变化。")
        }
        if parts.isEmpty { return "记下今天的日常，我就能给出更有依据的建议。" }
        return parts.joined()
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("最新记录").font(.headline)
                Spacer()
                NavigationLink("查看全部", destination: JournalView().environmentObject(store))
                    .font(.caption).foregroundStyle(CoveyTheme.accent)
            }
            let recent = store.data.entries.prefix(3)
            if recent.isEmpty {
                Text("记一笔或拍照后会出现在这里")
                    .font(.caption).foregroundStyle(CoveyTheme.ink2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
            ForEach(recent) { entry in
                EntryRow(entry: entry)
            }
        }
    }

    // MARK: - 操作

    private func markReminderDone(_ id: String) {
        if let i = store.data.reminders.firstIndex(where: { $0.id == id }) {
            store.data.reminders[i].done = true
        }
    }

    private var photoNoteSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                if let img = pendingPhoto {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .frame(maxHeight: 300)
                }
                TextField("这张照片里发生了什么？（可留空）", text: $photoNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Spacer()
                HStack {
                    Button("取消") { pendingPhoto = nil; photoNote = ""; showPhotoNote = false }
                        .buttonStyle(.bordered).tint(CoveyTheme.ink2)
                    Button("保存") {
                        if let img = pendingPhoto {
                            let resized = resizeImage(img, maxSide: 900)
                            let photoData = resized.jpegData(compressionQuality: 0.75)
                            store.addEntry(Entry(id: uid("e"), ts: Date(), type: .photo, text: photoNote.trimmed, photoData: photoData))
                        }
                        pendingPhoto = nil; photoNote = ""; showPhotoNote = false
                    }
                    .buttonStyle(.borderedProminent).tint(CoveyTheme.accent)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(18)
            .background(CoveyTheme.bg)
            .navigationTitle("记一张照片")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    func resizeImage(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height))
        if scale >= 1 { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

extension Notification.Name {
    static let askAI = Notification.Name("covey.askAI")
    static let switchTab = Notification.Name("covey.switchTab")
}

// MARK: - 记录行组件（今日预览 & 手账共用）

struct EntryRow: View {
    let entry: Entry
    @EnvironmentObject var store: Store
    @State private var showDelete = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11).fill(tagColor(entry.type.rawValue).opacity(0.12))
                Image(systemName: entry.type.symbol)
                    .font(.subheadline)
                    .foregroundStyle(tagColor(entry.type.rawValue))
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.type.label)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .foregroundStyle(tagColor(entry.type.rawValue))
                        .background(tagColor(entry.type.rawValue).opacity(0.12))
                        .clipShape(Capsule())
                    if let amount = entry.amount {
                        Text("¥\(String(format: "%.2f", amount))")
                            .font(.caption.bold()).foregroundStyle(CoveyTheme.accent)
                    }
                }
                if !entry.text.isEmpty {
                    Text(entry.text).font(.subheadline).lineLimit(nil)
                }
                if let data = entry.photoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(maxHeight: 220)
                }
                Text("\(fmtShortTime(entry.ts)) · \(store.memberName(entry.by))")
                    .font(.caption2).foregroundStyle(CoveyTheme.ink3)
            }
            Spacer()
        }
        .padding(12)
        .background(CoveyTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(CoveyTheme.line))
        .overlay(alignment: .leading) {
            Rectangle().fill(tagColor(entry.type.rawValue)).frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .contentShape(Rectangle())
        .onTapGesture { showDelete = true }
        .confirmationDialog("删除这条记录？", isPresented: $showDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) { store.deleteEntry(entry.id) }
            Button("取消", role: .cancel) {}
        }
    }
}
