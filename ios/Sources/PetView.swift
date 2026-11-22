// 同窝 Covey · 宠物页
import SwiftUI

struct PetView: View {
    @EnvironmentObject var store: Store
    @State private var showProfile = false
    @State private var showWeight = false
    @State private var showMember = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    profileCard
                    infoCard
                    weightsCard
                    membersCard
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(CoveyTheme.bg)
            .navigationTitle("宠物")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showProfile) { ProfileSheet().environmentObject(store) }
            .sheet(isPresented: $showWeight) { WeightSheet().environmentObject(store) }
            .sheet(isPresented: $showMember) { MemberSheet().environmentObject(store) }
        }
    }

    private var profileCard: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(CoveyTheme.accent)
                .frame(width: 64, height: 64)
                .overlay(Text(String(store.data.pet.name.prefix(1))).font(.title.bold()).foregroundStyle(.white))
            Text(store.data.pet.name).font(.title2.bold())
            Text(speciesLabel + (store.data.pet.breed.isEmpty ? "" : " · " + store.data.pet.breed))
                .font(.subheadline).foregroundStyle(CoveyTheme.ink2)
            Button { showProfile = true } label: {
                Label("编辑档案", systemImage: "pencil")
                    .font(.subheadline)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(CoveyTheme.card)
                    .overlay(Capsule().stroke(CoveyTheme.line))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain).foregroundStyle(CoveyTheme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(CoveyTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(CoveyTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var infoCard: some View {
        let pet = store.data.pet
        return VStack(alignment: .leading, spacing: 8) {
            Text("基本信息").font(.headline)
            infoRow("物种", speciesLabel)
            infoRow("品种", pet.breed.isEmpty ? "未填写" : pet.breed)
            infoRow("生日", pet.birthday.isEmpty ? "未填写" : pet.birthday + (ageText.isEmpty ? "" : "（\(ageText)）"))
            infoRow("当前体重", pet.weight.isEmpty ? "未记录" : pet.weight + " kg")
        }
        .padding(14)
        .background(CoveyTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(CoveyTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var weightsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("体重记录").font(.headline)
                Spacer()
                Button("+ 记录") { showWeight = true }
                    .font(.caption).foregroundStyle(CoveyTheme.accent)
            }
            if store.data.weights.isEmpty {
                Text("记录体重可以观察成长趋势")
                    .font(.caption).foregroundStyle(CoveyTheme.ink2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            ForEach(store.data.weights.suffix(8).reversed()) { w in
                HStack {
                    Text(fullDateCN(w.date)).font(.caption).foregroundStyle(CoveyTheme.ink2)
                    Spacer()
                    Text("\(w.kg) kg").font(.subheadline.bold())
                }
            }
        }
        .padding(14)
        .background(CoveyTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(CoveyTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var membersCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("家庭成员").font(.headline)
                Spacer()
                Button("+ 添加") { showMember = true }
                    .font(.caption).foregroundStyle(CoveyTheme.accent)
            }
            Text("成员仅保存在本机，用于区分谁完成了照护。")
                .font(.caption2).foregroundStyle(CoveyTheme.ink2)
            ForEach(store.data.members) { m in
                HStack {
                    Text(m.name).font(.subheadline)
                    if m.id == store.data.activeMember {
                        Text("当前").font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .foregroundStyle(CoveyTheme.blue)
                            .background(CoveyTheme.blueSoft).clipShape(Capsule())
                    }
                    Spacer()
                    Text(m.role == "owner" ? "主人" : m.role == "caregiver" ? "照护人" : "围观")
                        .font(.caption).foregroundStyle(CoveyTheme.ink2)
                    if m.id != store.data.activeMember {
                        Button("切换") { store.data.activeMember = m.id }
                            .font(.caption).foregroundStyle(CoveyTheme.accent)
                    }
                }
            }
        }
        .padding(14)
        .background(CoveyTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(CoveyTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var speciesLabel: String {
        speciesOptions.first { $0.key == store.data.pet.species }?.label ?? "其他"
    }

    private var ageText: String {
        guard !store.data.pet.birthday.isEmpty,
              let birth = dateFormatterCN.date(from: store.data.pet.birthday) else { return "" }
        let age = Calendar.current.dateComponents([.year], from: birth, to: Date()).year ?? 0
        return age >= 0 ? "\(age) 岁" : ""
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(CoveyTheme.ink2)
            Spacer()
            Text(value).font(.subheadline)
        }
    }
}
