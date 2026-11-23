import Foundation
import Combine

enum RunState: Equatable {
    case idle
    case running
    case paused
}

@MainActor
final class RunSessionManager: ObservableObject {
    @Published private(set) var state: RunState = .idle
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var splits: [KilometerSplit] = []
    @Published private(set) var averageHR: Int?
    @Published private(set) var maxHR: Int?

    /// Riepilogo pronto al termine della corsa (prima del salvataggio)
    @Published var pendingSummary: WorkoutSession?
    @Published private(set) var isMeasuringHRR: Bool = false
    @Published private(set) var hrrRemainingSeconds: Int = 60
    @Published private(set) var hrrStartBPM: Int?
    @Published private(set) var hrrMeasuredDrop: Int?

    private let heartRateManager: HeartRateManager
    private let locationManager: LocationManager
    private let voiceCoach: VoiceCoach
    private let store: WorkoutStore

    private var timer: Timer?
    private var hrrTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private var totalHRSum: Int = 0
    private var totalHRCount: Int = 0
    private var currentKmHRSum: Int = 0
    private var currentKmHRCount: Int = 0

    private var completedKilometers: Int = 0
    private var lastKmTimestampSeconds: TimeInterval = 0

    // Gestione anti-spam per gli avvisi vocali fuori zona
    private enum ZoneBreach {
        case high
        case low
    }
    private var activeBreach: ZoneBreach?
    private var breachStartedAt: Date?
    private var lastVoiceAlertAt: Date?
    private let sustainedBreachSeconds: TimeInterval = 6.0

    init(
        heartRateManager: HeartRateManager,
        locationManager: LocationManager,
        voiceCoach: VoiceCoach,
        store: WorkoutStore
    ) {
        self.heartRateManager = heartRateManager
        self.locationManager = locationManager
        self.voiceCoach = voiceCoach
        self.store = store

        setupBindings()
    }

    var averagePaceSecondsPerKm: TimeInterval? {
        let km = locationManager.totalDistanceMeters / 1000.0
        guard km >= 0.05, elapsedSeconds > 0 else { return nil }
        return elapsedSeconds / km
    }

    private func setupBindings() {
        heartRateManager.$currentBPM
            .compactMap { $0 }
            .sink { [weak self] bpm in
                self?.handleHeartRateSample(bpm)
            }
            .store(in: &cancellables)

        locationManager.$totalDistanceMeters
            .sink { [weak self] distanceMeters in
                self?.handleDistanceUpdate(distanceMeters)
            }
            .store(in: &cancellables)
    }

    func startRun() {
        guard state == .idle else { return }
        resetCounters()

        state = .running
        locationManager.startTracking()
        voiceCoach.configureAudioSessionForRun()
        voiceCoach.announceRunStarted(targetRange: store.settings.targetRange)

        startElapsedTimer()
    }

    func pauseRun() {
        guard state == .running else { return }
        state = .paused
        timer?.invalidate()
        timer = nil
        locationManager.pauseTracking()
        activeBreach = nil
        breachStartedAt = nil
        voiceCoach.announcePaused()
    }

    func resumeRun() {
        guard state == .paused else { return }
        state = .running
        locationManager.resumeTracking()
        voiceCoach.announceResumed()
        startElapsedTimer()
    }

    func stopRun() {
        guard state == .running || state == .paused else { return }
        timer?.invalidate()
        timer = nil
        state = .idle

        let finalDistance = locationManager.totalDistanceMeters
        let finalRoute = locationManager.routePoints
        let finalDuration = elapsedSeconds
        let finalAvgPace = averagePaceSecondsPerKm
        let finalAvgHR = averageHR
        let finalMaxHR = maxHR
        let finalSplits = splits

        locationManager.stopTracking()

        let settings = store.settings
        let recoveryHours = RecoveryEstimator.estimateRecoveryHours(
            durationSeconds: finalDuration,
            averageHR: finalAvgHR,
            maxHRSetting: settings.effectiveMaxHR,
            hrr1MinDrop: nil
        )

        voiceCoach.announceFinished(distanceKm: finalDistance / 1000.0, avgHR: finalAvgHR)

        pendingSummary = WorkoutSession(
            id: UUID(),
            date: Date(),
            durationSeconds: finalDuration,
            distanceMeters: finalDistance,
            averagePaceSecondsPerKm: finalAvgPace,
            averageHR: finalAvgHR,
            maxHR: finalMaxHR,
            targetMinBPM: settings.targetRange.lowerBound,
            targetMaxBPM: settings.targetRange.upperBound,
            zoneLabel: settings.activeLabel,
            splits: finalSplits,
            route: finalRoute,
            estimatedRecoveryHours: recoveryHours,
            hrr1MinDrop: nil
        )

        hrrMeasuredDrop = nil
        hrrStartBPM = heartRateManager.currentBPM
        isMeasuringHRR = false
        hrrRemainingSeconds = 60
    }

    func startOneMinuteHRRTest() {
        guard let startBPM = heartRateManager.currentBPM, pendingSummary != nil else { return }
        hrrTimer?.invalidate()
        hrrStartBPM = startBPM
        hrrMeasuredDrop = nil
        hrrRemainingSeconds = 60
        isMeasuringHRR = true

        hrrTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.hrrRemainingSeconds > 1 {
                    self.hrrRemainingSeconds -= 1
                } else {
                    self.finishHRRTest()
                }
            }
        }
    }

    func cancelHRRTest() {
        hrrTimer?.invalidate()
        hrrTimer = nil
        isMeasuringHRR = false
    }

    private func finishHRRTest() {
        hrrTimer?.invalidate()
        hrrTimer = nil
        isMeasuringHRR = false
        hrrRemainingSeconds = 0

        guard let startBPM = hrrStartBPM,
              let endBPM = heartRateManager.currentBPM,
              let current = pendingSummary else {
            return
        }

        let drop = max(0, startBPM - endBPM)
        hrrMeasuredDrop = drop

        let updatedHours = RecoveryEstimator.estimateRecoveryHours(
            durationSeconds: current.durationSeconds,
            averageHR: current.averageHR,
            maxHRSetting: store.settings.effectiveMaxHR,
            hrr1MinDrop: drop
        )

        pendingSummary = WorkoutSession(
            id: current.id,
            date: current.date,
            durationSeconds: current.durationSeconds,
            distanceMeters: current.distanceMeters,
            averagePaceSecondsPerKm: current.averagePaceSecondsPerKm,
            averageHR: current.averageHR,
            maxHR: current.maxHR,
            targetMinBPM: current.targetMinBPM,
            targetMaxBPM: current.targetMaxBPM,
            zoneLabel: current.zoneLabel,
            splits: current.splits,
            route: current.route,
            estimatedRecoveryHours: updatedHours,
            hrr1MinDrop: drop
        )

        voiceCoach.speak("Recupero cardiaco misurato: meno \(drop) battiti in un minuto.", interrupt: true)
    }

    func savePendingWorkout() {
        cancelHRRTest()
        if let summary = pendingSummary {
            store.addWorkout(summary)
        }
        pendingSummary = nil
        resetCounters()
        voiceCoach.deactivateAudioSession()
    }

    func discardPendingWorkout() {
        cancelHRRTest()
        pendingSummary = nil
        resetCounters()
        voiceCoach.deactivateAudioSession()
    }

    private func startElapsedTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.state == .running else { return }
                self.elapsedSeconds += 1
            }
        }
    }

    private func resetCounters() {
        elapsedSeconds = 0
        splits = []
        averageHR = nil
        maxHR = nil
        totalHRSum = 0
        totalHRCount = 0
        currentKmHRSum = 0
        currentKmHRCount = 0
        completedKilometers = 0
        lastKmTimestampSeconds = 0
        activeBreach = nil
        breachStartedAt = nil
        lastVoiceAlertAt = nil
    }

    private func handleHeartRateSample(_ bpm: Int) {
        guard state == .running else { return }

        totalHRSum += bpm
        totalHRCount += 1
        averageHR = Int((Double(totalHRSum) / Double(totalHRCount)).rounded())
        maxHR = max(maxHR ?? bpm, bpm)

        currentKmHRSum += bpm
        currentKmHRCount += 1

        evaluateHeartRateTarget(bpm: bpm)
    }

    private func evaluateHeartRateTarget(bpm: Int) {
        let range = store.settings.targetRange
        let now = Date()

        let currentBreach: ZoneBreach?
        if bpm > range.upperBound {
            currentBreach = .high
        } else if bpm < range.lowerBound {
            // Nei primi 30 secondi di riscaldamento evita di dire subito "puoi accelerare"
            currentBreach = elapsedSeconds >= 30 ? .low : nil
        } else {
            currentBreach = nil
        }

        guard let breach = currentBreach else {
            activeBreach = nil
            breachStartedAt = nil
            return
        }

        if activeBreach != breach {
            activeBreach = breach
            breachStartedAt = now
            return
        }

        guard let started = breachStartedAt,
              now.timeIntervalSince(started) >= sustainedBreachSeconds else {
            return
        }

        let cooldown = TimeInterval(max(10, store.settings.alertCooldownSeconds))
        if let lastAlert = lastVoiceAlertAt, now.timeIntervalSince(lastAlert) < cooldown {
            return
        }

        lastVoiceAlertAt = now
        switch breach {
        case .high:
            voiceCoach.announceTooFast(bpm: bpm)
        case .low:
            voiceCoach.announceCanGoFaster(bpm: bpm)
        }
    }

    private func handleDistanceUpdate(_ distanceMeters: Double) {
        guard state == .running else { return }

        let nextKmIndex = completedKilometers + 1
        let thresholdMeters = Double(nextKmIndex) * 1000.0

        if distanceMeters >= thresholdMeters {
            let splitDuration = max(1, elapsedSeconds - lastKmTimestampSeconds)
            let kmAvgHR: Int? = currentKmHRCount > 0
                ? Int((Double(currentKmHRSum) / Double(currentKmHRCount)).rounded())
                : heartRateManager.currentBPM

            let split = KilometerSplit(
                kilometerIndex: nextKmIndex,
                splitDurationSeconds: splitDuration,
                averageHR: kmAvgHR,
                paceSecondsPerKm: splitDuration
            )
            splits.append(split)

            completedKilometers = nextKmIndex
            lastKmTimestampSeconds = elapsedSeconds
            currentKmHRSum = 0
            currentKmHRCount = 0

            // Evita che subito dopo l'annuncio del km parta un altro avviso vocale
            lastVoiceAlertAt = Date()

            voiceCoach.announceKilometerSplit(
                kmIndex: nextKmIndex,
                splitDuration: splitDuration,
                averageHR: kmAvgHR,
                currentBPM: heartRateManager.currentBPM,
                targetRange: store.settings.targetRange
            )
        }
    }
}
