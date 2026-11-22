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
                    careCard
                    insightGrid
                    reminderCard
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
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(weekdayCN(Date()))
                    .font(.subheadline)
                    .foregroundStyle(CoveyTheme.ink2)
                Text("\(store.data.pet.name)的日常")
                    .font(.title.bold())
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "heart.fill").font(.caption)
                Text("连续照顾 \(store.careStreak()) 天").font(.caption.bold())
            }
            .foregroundStyle(Color(hex: 0x8A6A1F))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(CoveyTheme.goldSoft)
            .clipShape(Capsule())
        }
        .padding(.top, 8)
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
                let prompt = "请根据我家宠物\(store.data.pet.name)最近的照护记录和待办提醒，给我 3 条简短、可执行的建议。"
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

    private var careCard: some View {
        let prog = store.careProgress()
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(CoveyTheme.line, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: prog.total == 0 ? 0 : CGFloat(prog.done) / CGFloat(prog.total))
                        .stroke(CoveyTheme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(prog.done) / \(prog.total) 今日照护").font(.subheadline.bold())
                    Text(prog.done == prog.total && prog.total > 0 ? "今天照顾得很到位" : "完成一件是一件")
                        .font(.caption).foregroundStyle(CoveyTheme.ink2)
                }
            }
            ForEach(store.data.tasks) { task in
                let done = store.isTaskDone(task.id)
                let comp = store.data.completions[dateKey()]?[task.id]
                HStack(spacing: 12) {
                    Button { store.toggleTask(task.id) } label: {
                        ZStack {
                            Circle().stroke(done ? CoveyTheme.sage : CoveyTheme.line, lineWidth: 2)
                            if done {
                                Circle().fill(CoveyTheme.sage)
                                Image(systemName: "checkmark").font(.caption2.bold()).foregroundStyle(.white)
                            }
                        }
                        .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(.subheadline.weight(.semibold))
                            .strikethrough(done)
                            .foregroundStyle(done ? CoveyTheme.ink3 : CoveyTheme.ink)
                        HStack(spacing: 6) {
                            Text(taskTypeLabel(task.type))
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .foregroundStyle(tagColor(task.type))
                                .background(tagColor(task.type).opacity(0.12))
                                .clipShape(Capsule())
                            Text(comp.map { timeKey($0.at) + " 完成" } ?? task.time)
                                .font(.caption2).foregroundStyle(CoveyTheme.ink3)
                            if let comp { Text("· \(store.memberName(comp.by))").font(.caption2).foregroundStyle(CoveyTheme.ink3) }
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .background(.white)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(CoveyTheme.line))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(14)
        .background(CoveyTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(CoveyTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var insightGrid: some View {
        let week = store.weekStats()
        let due = store.remindersDueSoon().count
        let lastW = store.data.weights.last
        let daysW: Int? = lastW.map { Calendar.current.dateComponents([.day], from: dateFormatterCN.date(from: $0.date) ?? Date(), to: Date()).day ?? 0 }
        let weightValue = lastW.map { "\($0.kg) kg" } ?? "—"
        var weightLabel = "还没有体重记录"
        if let d = daysW {
            weightLabel = "最近体重 · \(d == 0 ? "今天" : "\(d) 天前") 记录"
        }
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            insightTile(value: "\(week.rate)%", label: "近 7 天照护完成率（\(week.done)/\(week.total)）")
            insightTile(value: "\(due)", label: "7 天内待办提醒")
            insightTile(value: weightValue, label: weightLabel)
            insightTile(value: "\(store.data.weights.count)", label: "体重记录次数")
        }
    }

    private func insightTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption2).foregroundStyle(CoveyTheme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(CoveyTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CoveyTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var reminderCard: some View {
        let list = store.remindersDueSoon()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("照护提醒").font(.headline)
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
                Button { NotificationCenter.default.post(name: .askAI, object: "请根据我家宠物\(store.data.pet.name)最近的照护记录和待办提醒，给我 3 条简短、可执行的建议。") } label: {
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
        let week = store.weekStats()
        var parts: [String] = []
        if week.rate >= 80 { parts.append("这周照护完成率 \(week.rate)%，状态不错。") }
        else if week.total > 0 { parts.append("这周照护完成率 \(week.rate)%，可以留意漏掉的环节。") }
        let due = store.remindersDueSoon().count
        if due > 0 { parts.append("\(due) 件提醒在 7 天内到期。") }
        if let lastW = store.data.weights.last {
            let days = Calendar.current.dateComponents([.day], from: dateFormatterCN.date(from: lastW.date) ?? Date(), to: Date()).day ?? 0
            if days > 30 { parts.append("体重已经 \(days) 天没记录了。") }
        }
        if parts.isEmpty { return "记录越多，我越能给出有依据的建议。先完成今天的照护吧。" }
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
                Text("还没有记录，完成照护或记一笔后会出现在这里")
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
