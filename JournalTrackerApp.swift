import SwiftUI
import UniformTypeIdentifiers

struct ProgramPlan: Codable {
    var foodBlocksPerDay: String = "14"
    var waterOuncesPerDay: String = "88"
    var cardioSessionsPerWeek: String = ""
    var strengthSessionsPerWeek: String = ""
    var weeklyExerciseActivities: String = ""
    var habits: [String] = ["", "", ""]
    var goals: [String] = ["", ""]
    var whyImportant: [String] = ["", "", ""]
    var values: [String] = ["", "", ""]
    var encouragement: String = ""
}

struct MealEntry: Codable, Identifiable {
    var id = UUID()
    var targetBlocks: String = ""
    var time: Date = Date()
    var whatIAte: String = ""
}

struct ExerciseEntry: Codable, Identifiable {
    var id = UUID()
    var activity: String = ""
    var duration: String = ""
}

struct DailyEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var meals: [MealEntry] = [MealEntry(), MealEntry(), MealEntry(), MealEntry()]
    var exercise: [ExerciseEntry] = [ExerciseEntry(), ExerciseEntry(), ExerciseEntry()]
    var waterTarget: String = "88"
    var waterActual: String = "0"
    var successes: String = ""
    var improveTomorrow: String = ""
}

@MainActor
final class JournalStore: ObservableObject {
    @Published var program = ProgramPlan()
    @Published var entries: [String: DailyEntry] = [:]
    @Published var selectedDate = Calendar.current.startOfDay(for: Date())

    private let programKey = "jt.program"
    private let entriesKey = "jt.entries"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() { load() }

    func key(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Calendar.current.startOfDay(for: date))
    }

    func entry(for date: Date) -> Binding<DailyEntry> {
        let k = key(for: date)
        if entries[k] == nil { entries[k] = DailyEntry(date: Calendar.current.startOfDay(for: date)) }
        return Binding(
            get: { self.entries[k] ?? DailyEntry(date: Calendar.current.startOfDay(for: date)) },
            set: { self.entries[k] = $0; self.save() }
        )
    }

    func moveDay(_ offset: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) {
            selectedDate = Calendar.current.startOfDay(for: d)
        }
    }

    func addWater(_ ounces: Int) {
        let k = key(for: selectedDate)
        if entries[k] == nil { entries[k] = DailyEntry(date: selectedDate) }
        let current = Int(entries[k]?.waterActual ?? "0") ?? 0
        entries[k]?.waterActual = String(current + ounces)
        save()
    }

    func waterProgress(for entry: DailyEntry) -> Double {
        let target = Double(entry.waterTarget) ?? 0
        let actual = Double(entry.waterActual) ?? 0
        guard target > 0 else { return 0 }
        return min(actual / target, 1.0)
    }

    func exportCSV(for entry: DailyEntry) -> URL? {
        var rows: [[String]] = [["Section", "Item", "Value"]]
        let day = key(for: entry.date)
        rows += [["Daily","Date",day],["Daily","Water Target",entry.waterTarget],["Daily","Water Actual",entry.waterActual],["Daily","Successes",entry.successes],["Daily","Improve Tomorrow",entry.improveTomorrow]]
        for (i,m) in entry.meals.enumerated() {
            rows += [["Meal \(i+1)","Target Blocks",m.targetBlocks],["Meal \(i+1)","Time",timeString(m.time)],["Meal \(i+1)","What I Ate",m.whatIAte]]
        }
        for (i,x) in entry.exercise.enumerated() {
            rows += [["Exercise \(i+1)","Activity",x.activity],["Exercise \(i+1)","Duration",x.duration]]
        }
        let csv = rows.map { $0.map(csvEscape).joined(separator: ",") }.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("journal-\(day).csv")
        try? csv.data(using: .utf8)?.write(to: url)
        return url
    }

    func save() {
        if let p = try? encoder.encode(program) { UserDefaults.standard.set(p, forKey: programKey) }
        if let e = try? encoder.encode(entries) { UserDefaults.standard.set(e, forKey: entriesKey) }
    }

    private func load() {
        if let p = UserDefaults.standard.data(forKey: programKey), let decoded = try? decoder.decode(ProgramPlan.self, from: p) { program = decoded }
        if let e = UserDefaults.standard.data(forKey: entriesKey), let decoded = try? decoder.decode([String: DailyEntry].self, from: e) { entries = decoded }
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\n") || value.contains("\"") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}

struct JournalTrackerApp: App {
    @StateObject private var store = JournalStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            ProgramPagesView()
                .tabItem { Label("Program", systemImage: "list.bullet.rectangle") }
            DailyJournalView()
                .tabItem { Label("Today", systemImage: "square.and.pencil") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
        .tint(Color.teal)
    }
}

struct ProgramPagesView: View {
    @EnvironmentObject var store: JournalStore
    @State private var page = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                Form {
                    Section("Game Plan for Success") {
                        TextField("Food blocks per day", text: $store.program.foodBlocksPerDay)
                            .keyboardType(.numberPad)
                        TextField("Water ounces per day", text: $store.program.waterOuncesPerDay)
                            .keyboardType(.numberPad)
                        TextField("Cardio sessions per week (30+ min)", text: $store.program.cardioSessionsPerWeek)
                            .keyboardType(.numberPad)
                        TextField("Strength sessions per week (30+ min)", text: $store.program.strengthSessionsPerWeek)
                            .keyboardType(.numberPad)
                        TextEditor(text: $store.program.weeklyExerciseActivities)
                            .frame(minHeight: 120)
                    }
                }
                .tag(0)

                Form {
                    Section("Habits I'm committing to focus on") {
                        ForEach(0..<3, id: \.self) { i in
                            TextField("Habit \(i + 1)", text: Binding(
                                get: { store.program.habits[i] },
                                set: { store.program.habits[i] = $0; store.save() }
                            ))
                        }
                    }
                    Section("My goals for the program") {
                        ForEach(0..<2, id: \.self) { i in
                            TextField("Goal \(i + 1)", text: Binding(
                                get: { store.program.goals[i] },
                                set: { store.program.goals[i] = $0; store.save() }
                            ))
                        }
                    }
                }
                .tag(1)

                Form {
                    Section("Why my results are important to me") {
                        ForEach(0..<3, id: \.self) { i in
                            TextField("Reason \(i + 1)", text: Binding(
                                get: { store.program.whyImportant[i] },
                                set: { store.program.whyImportant[i] = $0; store.save() }
                            ))
                        }
                    }
                    Section("I value") {
                        ForEach(0..<3, id: \.self) { i in
                            TextField("Value \(i + 1)", text: Binding(
                                get: { store.program.values[i] },
                                set: { store.program.values[i] = $0; store.save() }
                            ))
                        }
                    }
                    Section("When I need encouragement, I will tell myself") {
                        TextField("Encouragement", text: $store.program.encouragement)
                    }
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .navigationTitle("Program")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("Page \(page + 1) of 3")
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: store.program) { _, _ in store.save() }
        }
    }
}

struct DailyJournalView: View {
    @EnvironmentObject var store: JournalStore
    @State private var exportURL: URL?
    @State private var showShare = false

    var body: some View {
        let entry = store.entry(for: store.selectedDate)
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Button { store.moveDay(-1) } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        VStack(spacing: 4) {
                            Text(store.selectedDate, format: .dateTime.weekday(.wide).month(.wide).day().year())
                                .font(.headline)
                            DatePicker("Date", selection: Binding(
                                get: { store.selectedDate },
                                set: { store.selectedDate = Calendar.current.startOfDay(for: $0) }
                            ), displayedComponents: [.date])
                            .labelsHidden()
                        }
                        Spacer()
                        Button { store.moveDay(1) } label: { Image(systemName: "chevron.right") }
                    }
                    .buttonStyle(.borderless)
                }

                Section("Meals") {
                    ForEach(entry.wrappedValue.meals.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Meal \(i + 1)")
                                .font(.headline)
                            HStack(alignment: .top, spacing: 12) {
                                VStack(spacing: 12) {
                                    TextField("Target Blocks", text: Binding(
                                        get: { entry.wrappedValue.meals[i].targetBlocks },
                                        set: { entry.wrappedValue.meals[i].targetBlocks = $0 }
                                    ))
                                    .keyboardType(.numberPad)
                                    DatePicker("Time", selection: Binding(
                                        get: { entry.wrappedValue.meals[i].time },
                                        set: { entry.wrappedValue.meals[i].time = $0 }
                                    ), displayedComponents: [.hourAndMinute])
                                }
                                VStack(alignment: .leading) {
                                    Text("What I ate")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    TextEditor(text: Binding(
                                        get: { entry.wrappedValue.meals[i].whatIAte },
                                        set: { entry.wrappedValue.meals[i].whatIAte = $0 }
                                    ))
                                    .frame(minHeight: 96)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section("Exercise") {
                    ForEach(entry.wrappedValue.exercise.indices, id: \.self) { i in
                        VStack(spacing: 12) {
                            TextField("Activity", text: Binding(
                                get: { entry.wrappedValue.exercise[i].activity },
                                set: { entry.wrappedValue.exercise[i].activity = $0 }
                            ))
                            TextField("Duration", text: Binding(
                                get: { entry.wrappedValue.exercise[i].duration },
                                set: { entry.wrappedValue.exercise[i].duration = $0 }
                            ))
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Water") {
                    TextField("Target oz", text: Binding(
                        get: { entry.wrappedValue.waterTarget },
                        set: { entry.wrappedValue.waterTarget = $0 }
                    ))
                    .keyboardType(.numberPad)
                    TextField("Actual oz", text: Binding(
                        get: { entry.wrappedValue.waterActual },
                        set: { entry.wrappedValue.waterActual = $0 }
                    ))
                    .keyboardType(.numberPad)
                    HStack {
                        ForEach([4, 8, 12, 16], id: \.self) { amount in
                            Button("+\(amount)") { store.addWater(amount) }
                                .buttonStyle(.bordered)
                        }
                    }
                    ProgressView(value: store.waterProgress(for: entry.wrappedValue))
                    Text("\(entry.wrappedValue.waterActual) of \(entry.wrappedValue.waterTarget) ounces")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Today's Successes") {
                    TextEditor(text: Binding(
                        get: { entry.wrappedValue.successes },
                        set: { entry.wrappedValue.successes = $0 }
                    ))
                    .frame(minHeight: 120)
                }

                Section("What I'd like to improve on tomorrow") {
                    TextEditor(text: Binding(
                        get: { entry.wrappedValue.improveTomorrow },
                        set: { entry.wrappedValue.improveTomorrow = $0 }
                    ))
                    .frame(minHeight: 120)
                }

                Section("Export") {
                    Button("Export current day as CSV for Excel") {
                        exportURL = store.exportCSV(for: entry.wrappedValue)
                        showShare = exportURL != nil
                    }
                    Button("Export current screen as PDF") {
                    }
                    .disabled(true)
                    Text("PDF export is best added with a small UIKit print/share bridge in the next pass.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Journal Tracker")
            .sheet(isPresented: $showShare) {
                if let exportURL {
                    ShareSheet(items: [exportURL])
                }
            }
            .onChange(of: entry.wrappedValue) { _, _ in store.save() }
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: JournalStore

    var sortedEntries: [DailyEntry] {
        store.entries.values.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                if sortedEntries.isEmpty {
                    ContentUnavailableView("No entries yet", systemImage: "calendar.badge.exclamationmark")
                } else {
                    ForEach(sortedEntries) { entry in
                        Button {
                            store.selectedDate = entry.date
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.date, format: .dateTime.weekday(.wide).month(.wide).day().year())
                                    .foregroundStyle(.primary)
                                Text("Water: \(entry.waterActual)/\(entry.waterTarget) oz")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
