import SwiftUI

@main
struct CardioPaceRunApp: App {
    @StateObject private var store: WorkoutStore
    @StateObject private var heartRateManager: HeartRateManager
    @StateObject private var locationManager: LocationManager
    @StateObject private var voiceCoach: VoiceCoach
    @StateObject private var runManager: RunSessionManager

    init() {
        let store = WorkoutStore()
        let hr = HeartRateManager()
        let loc = LocationManager()
        let voice = VoiceCoach()
        let runner = RunSessionManager(
            heartRateManager: hr,
            locationManager: loc,
            voiceCoach: voice,
            store: store
        )

        _store = StateObject(wrappedValue: store)
        _heartRateManager = StateObject(wrappedValue: hr)
        _locationManager = StateObject(wrappedValue: loc)
        _voiceCoach = StateObject(wrappedValue: voice)
        _runManager = StateObject(wrappedValue: runner)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .environmentObject(heartRateManager)
                .environmentObject(locationManager)
                .environmentObject(voiceCoach)
                .environmentObject(runManager)
        }
    }
}
