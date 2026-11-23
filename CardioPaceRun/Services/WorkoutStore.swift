import Foundation

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var settings: UserHRSettings {
        didSet { saveSettings() }
    }
    @Published private(set) var workouts: [WorkoutSession] = []

    private let settingsKey = "cardiopacerun.hrSettings.v1"
    private let workoutsFilename = "workouts.json"

    init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(UserHRSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = UserHRSettings()
        }
        loadWorkouts()
    }

    private var workoutsFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(workoutsFilename)
    }

    func addWorkout(_ session: WorkoutSession) {
        workouts.insert(session, at: 0)
        persistWorkouts()
    }

    func deleteWorkouts(at offsets: IndexSet) {
        workouts.remove(atOffsets: offsets)
        persistWorkouts()
    }

    func deleteWorkout(_ session: WorkoutSession) {
        workouts.removeAll { $0.id == session.id }
        persistWorkouts()
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    private func loadWorkouts() {
        guard let data = try? Data(contentsOf: workoutsFileURL),
              let decoded = try? JSONDecoder().decode([WorkoutSession].self, from: data) else {
            workouts = []
            return
        }
        workouts = decoded.sorted { $0.date > $1.date }
    }

    private func persistWorkouts() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(workouts) {
            try? data.write(to: workoutsFileURL, options: [.atomic])
        }
    }
}
