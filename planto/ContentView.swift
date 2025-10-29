//
//  ContentView.swift
//  planto
//
//  Created by Lyan on 29/04/1447 AH.
//
import SwiftUI
import UserNotifications
import Combine
import SwiftUI
import UserNotifications

// MARK: - Models

enum WaterSchedule: String, CaseIterable, Identifiable, Codable {
    case everyDay    = "Every day"
    case every2Days  = "Every 2 days"
    case every3Days  = "Every 3 days"
    case weekly      = "Once a week"
    case every10Days = "Every 10 days"
    case every2Weeks = "Every 2 weeks"
    var id: String { rawValue }
}

enum RoomLocation: String, CaseIterable, Identifiable, Codable {
    case bedroom = "Bedroom", livingRoom = "Living Room", kitchen = "Kitchen", balcony = "Balcony", bathroom = "Bathroom"
    var id: String { rawValue }
}

enum LightLevel: String, CaseIterable, Identifiable, Codable {
    case fullSun = "Full sun", partialSun = "Partial sun", lowLight = "Low light"
    var id: String { rawValue }
}

enum WaterAmountRange: String, CaseIterable, Identifiable, Codable {
    case r20_50   = "20-50 ml"
    case r50_100  = "50-100 ml"
    case r100_200 = "100-200 ml"
    case r200_300 = "200-300 ml"
    var id: String { rawValue }
}

struct Plant: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var room: RoomLocation
    var light: LightLevel
    var schedule: WaterSchedule
    var waterRange: WaterAmountRange
    var doneToday: Bool

    init(id: UUID = UUID(), name: String, room: RoomLocation, light: LightLevel,
         schedule: WaterSchedule, waterRange: WaterAmountRange, doneToday: Bool = false) {
        self.id = id; self.name = name; self.room = room; self.light = light
        self.schedule = schedule; self.waterRange = waterRange; self.doneToday = doneToday
    }
}

// MARK: - Notifications

final class NotificationManager {
    static let shared = NotificationManager(); private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.sound,.badge]) { _, err in
            if let err { print("Notif auth error:", err.localizedDescription) }
        }
    }

    func cancelAll(for plant: Plant) {
        let id = plant.id.uuidString
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id, id + "_first"])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id, id + "_first"])
    }

    func schedule(for plant: Plant, hour: Int = 9, minute: Int = 0) {
        cancelAll(for: plant)

        let content = UNMutableNotificationContent()
        content.title = "Water \(plant.name)"
        content.body  = "Room: \(plant.room.rawValue) • \(plant.light.rawValue) • \(plant.waterRange.rawValue)"
        content.sound = .default

        let id = plant.id.uuidString
        switch plant.schedule {
        case .everyDay:
            var c = DateComponents(); c.hour = hour; c.minute = minute; c.second = 0
            let trig = UNCalendarNotificationTrigger(dateMatching: c, repeats: true)
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trig))
        case .weekly, .every2Weeks, .every2Days, .every3Days, .every10Days:
            let first = secondsUntilNext(hour: hour, minute: minute)
            let interval = intervalSeconds(for: plant.schedule)
            UNUserNotificationCenter.current().add(UNNotificationRequest(
                identifier: id + "_first",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(first, 60), repeats: false)
            ))
            UNUserNotificationCenter.current().add(UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
            ))
        }
    }

    private func intervalSeconds(for s: WaterSchedule) -> TimeInterval {
        let day: TimeInterval = 24*60*60
        switch s {
        case .weekly:      return 7*day
        case .every2Weeks: return 14*day
        case .every2Days:  return 2*day
        case .every3Days:  return 3*day
        case .every10Days: return 10*day
        case .everyDay:    return day
        }
    }

    private func secondsUntilNext(hour: Int, minute: Int) -> TimeInterval {
        let cal = Calendar.current, now = Date()
        var c = cal.dateComponents([.year,.month,.day], from: now)
        c.hour = hour; c.minute = minute; c.second = 0
        let today = cal.date(from: c)!; if today > now { return today.timeIntervalSince(now) }
        return cal.date(byAdding: .day, value: 1, to: today)!.timeIntervalSince(now)
    }
}

// MARK: - Store

final class PlantsStore: ObservableObject {
    @AppStorage("plants_data") private var storedData: Data = Data()
    @AppStorage("hasOnboarded_v2") var hasOnboarded: Bool = false

    @Published var plants: [Plant] = [] { didSet { save() } }

    init() { load() }

    var completedCount: Int { plants.filter(\.doneToday).count }
    var progress: Double { plants.isEmpty ? 0 : Double(completedCount)/Double(plants.count) }

    func upsert(_ p: Plant) {
        if let i = plants.firstIndex(where: {$0.id == p.id}) { plants[i] = p } else { plants.append(p) }
        NotificationManager.shared.schedule(for: p)
    }

    func toggleDone(_ p: Plant) { if let i = plants.firstIndex(of: p) { plants[i].doneToday.toggle() } }

    func remove(_ p: Plant) {
        NotificationManager.shared.cancelAll(for: p)
        plants.removeAll { $0.id == p.id }
    }

    func delete(at offsets: IndexSet) {
        for i in offsets { NotificationManager.shared.cancelAll(for: plants[i]) }
        plants.remove(atOffsets: offsets)
    }

    private func save() {
        if let d = try? JSONEncoder().encode(plants) { storedData = d }
    }
    private func load() {
        guard !storedData.isEmpty, let arr = try? JSONDecoder().decode([Plant].self, from: storedData) else { plants = []; return }
        plants = arr
    }
}

// MARK: - App Root

struct ContentView: View {
    @StateObject private var store = PlantsStore()
    @State private var showEditor = false
    @State private var editingPlant: Plant? = nil

    var body: some View {
        NavigationStack {
            Group {
                // يطابق التسلسل في الصور: شاشة البداية -> sheet -> قائمة
                if !store.hasOnboarded || store.plants.isEmpty {
                    StartPage {
                        editingPlant = nil
                        showEditor = true
                    }
                } else {
                    MyPlantsView(
                        onAdd: { editingPlant = nil; showEditor = true },
                        onEdit: { plant in editingPlant = plant; showEditor = true }
                    )
                }
            }
            .background(Color.black.ignoresSafeArea())
            .sheet(isPresented: $showEditor) {
                PlantEditorSheet(plant: editingPlant) { result in
                    store.upsert(result)
                    store.hasOnboarded = true
                }
                .environmentObject(store)
            }
        }
        .environmentObject(store)
        .onAppear { NotificationManager.shared.requestAuthorization() }
    }
}

// MARK: - Start Screen (matches first image)

struct StartPage: View {
    var onGetStarted: () -> Void
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer(minLength: 60)

                Image("plantHero")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)

                VStack(spacing: 10) {
                    Text("Start your plant journey!")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                    Text("Now all your plants will be in one place and we will help you take care of them :) 🌿")
                        .font(.system(.callout, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onGetStarted()
                } label: {
                    Text("Set Plant Reminder")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.4, green: 0.87, blue: 0.78))
                                .shadow(color: Color(red: 0.4, green: 0.87, blue: 0.78).opacity(0.35), radius: 12, x: 0, y: 6)
                        )
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
    }
}

// MARK: - My Plants (matches list/progress images)

struct MyPlantsView: View {
    @EnvironmentObject private var store: PlantsStore
    @State private var showAllDoneToast = false

    var onAdd: () -> Void
    var onEdit: (Plant) -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {

                // Header: "My Plants 🌱"
                Text("My Plants 🌱")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

            
                ProgressSection(
                    progress: store.progress,
                    text: store.completedCount == 0
                    ? "Your plants are waiting for a sip 💦"
                    : "\(store.completedCount) of your plants feel loved today✨"
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                if store.plants.isEmpty {
            
                    EmptyHintView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.plants) { plant in
                                PlantRow(plant: plant, toggle: { store.toggleDone(plant) })
                                    .contentShape(Rectangle())
                                    .onTapGesture { onEdit(plant) }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) { store.remove(plant) } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                Divider().overlay(Color.white.opacity(0.08))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 80)
                    }
                }
            }

            // Floating +
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.black)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(Color(red: 0.4, green: 0.87, blue: 0.78))
                            .shadow(color: Color(red: 0.4, green: 0.87, blue: 0.78).opacity(0.4), radius: 12, x: 0, y: 6)
                    )
            }
            .padding(20)
        }
        .background(Color.black.ignoresSafeArea())
        .onChange(of: store.completedCount) { _, _ in
            withAnimation(.spring()) {
                showAllDoneToast = (store.completedCount == store.plants.count && !store.plants.isEmpty)
            }
        }
        .overlay {
            if showAllDoneToast {
                AllDoneToast()
                    .transition(.scale.combined(with: .opacity))
                    .onTapGesture { withAnimation { showAllDoneToast = false } }
            }
        }
    }
}

// MARK: - Components (Glass + Progress + Rows)

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)   // Glass Effect
                            .opacity(0.3)
                    )
            )
    }
}

struct ProgressSection: View {
    let progress: Double
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15)).frame(height: 8)
                    Capsule()
                        .fill(Color(red: 0.4, green: 0.87, blue: 0.78))
                        .frame(width: max(8, CGFloat(progress) * geo.size.width), height: 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

struct PlantRow: View {
    let plant: Plant
    var toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 6) {
                Image(systemName: "location.north")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text("in \(plant.room.rawValue)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }

            HStack(spacing: 14) {
                Button(action: toggle) {
                    Image(systemName: plant.doneToday ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28))
                        .foregroundColor(plant.doneToday ? Color(red: 0.4, green: 0.87, blue: 0.78) : .white.opacity(0.3))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    Text(plant.name)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundColor(.white)

                    HStack(spacing: 10) {
                        Label(plant.light.rawValue, systemImage: "sun.max.fill")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                        Label(plant.waterRange.rawValue, systemImage: "drop.fill")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }

                Spacer()
            }
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Editor Sheet (matches second image)

struct PlantEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PlantsStore

    var plant: Plant?
    var onSave: (Plant) -> Void

    @State private var name: String = ""
    @State private var room: RoomLocation = .bedroom
    @State private var light: LightLevel = .fullSun
    @State private var schedule: WaterSchedule = .everyDay
    @State private var waterRange: WaterAmountRange = .r20_50
    @FocusState private var isNameFocused: Bool

    init(plant: Plant?, onSave: @escaping (Plant) -> Void) {
        self.plant = plant; self.onSave = onSave
        _name = State(initialValue: plant?.name ?? "")
        _room = State(initialValue: plant?.room ?? .bedroom)
        _light = State(initialValue: plant?.light ?? .fullSun)
        _schedule = State(initialValue: plant?.schedule ?? .everyDay)
        _waterRange = State(initialValue: plant?.waterRange ?? .r20_50)
    }

    var isNameValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        GlassCard {
                            HStack {
                                Text("Plant Name")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                                Spacer()
                                TextField("Pothos", text: $name)
                                    .focused($isNameFocused)
                                    .multilineTextAlignment(.trailing)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }

                        GlassCard {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "location.north").foregroundColor(.white.opacity(0.9))
                                    Text("Room").font(.system(.body, design: .rounded)).foregroundColor(.white.opacity(0.9))
                                    Spacer()
                                    Picker("", selection: $room) { ForEach(RoomLocation.allCases) { Text($0.rawValue).tag($0) } }
                                        .tint(.white.opacity(0.8))
                                }
                                Divider().background(Color.white.opacity(0.1))
                                HStack {
                                    Image(systemName: "sun.max.fill").foregroundColor(.white.opacity(0.9))
                                    Text("Light").font(.system(.body, design: .rounded)).foregroundColor(.white.opacity(0.9))
                                    Spacer()
                                    Picker("", selection: $light) { ForEach(LightLevel.allCases) { Text($0.rawValue).tag($0) } }
                                        .tint(.white.opacity(0.8))
                                }
                            }
                        }

                        GlassCard {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "calendar").foregroundColor(.white.opacity(0.9))
                                    Text("Watering Days").font(.system(.body, design: .rounded)).foregroundColor(.white.opacity(0.9))
                                    Spacer()
                                    Picker("", selection: $schedule) { ForEach(WaterSchedule.allCases) { Text($0.rawValue).tag($0) } }
                                        .tint(.white.opacity(0.8))
                                }
                                Divider().background(Color.white.opacity(0.1))
                                HStack {
                                    Image(systemName: "drop.fill").foregroundColor(.white.opacity(0.9))
                                    Text("Water").font(.system(.body, design: .rounded)).foregroundColor(.white.opacity(0.9))
                                    Spacer()
                                    Picker("", selection: $waterRange) { ForEach(WaterAmountRange.allCases) { Text($0.rawValue).tag($0) } }
                                        .tint(.white.opacity(0.8))
                                }
                            }
                        }

                        if plant != nil {
                            Button(role: .destructive) {
                                if let p = plant { store.remove(p) }
                                dismiss()
                            } label: {
                                Text("Delete Reminder")
                                    .font(.system(.body, design: .rounded).weight(.medium))
                                    .foregroundColor(.red.opacity(0.9))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Set Reminder")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let p = Plant(
                            id: plant?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            room: room, light: light, schedule: schedule, waterRange: waterRange,
                            doneToday: plant?.doneToday ?? false
                        )
                        onSave(p); dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.black)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(isNameValid ? Color(red: 0.4, green: 0.87, blue: 0.78) : Color.gray.opacity(0.3))
                            )
                    }
                    .disabled(!isNameValid)
                }
            }
            .onAppear { if plant == nil { isNameFocused = true } }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Empty Hint + All Done

struct EmptyHintView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image("plantHero").resizable().scaledToFit().frame(width: 180, height: 180)
            Text("No plants yet")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(.white)
            Text("Tap the + button to add your first plant.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct AllDoneToast: View {
    var body: some View {
        VStack(spacing: 18) {
            Image("plantHero").resizable().scaledToFit().frame(width: 140, height: 140)
            Text("All Done! 🎉")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(.white)
            Text("All Reminders Completed")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 24).fill(Color.black.opacity(0.72)))
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 12)
        )
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
