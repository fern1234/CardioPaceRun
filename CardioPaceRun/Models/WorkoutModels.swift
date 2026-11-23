import Foundation
import CoreLocation

struct CoordinatePoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct KilometerSplit: Codable, Identifiable, Equatable {
    let id: UUID
    let kilometerIndex: Int
    let splitDurationSeconds: TimeInterval
    let averageHR: Int?
    let paceSecondsPerKm: TimeInterval

    init(
        id: UUID = UUID(),
        kilometerIndex: Int,
        splitDurationSeconds: TimeInterval,
        averageHR: Int?,
        paceSecondsPerKm: TimeInterval
    ) {
        self.id = id
        self.kilometerIndex = kilometerIndex
        self.splitDurationSeconds = splitDurationSeconds
        self.averageHR = averageHR
        self.paceSecondsPerKm = paceSecondsPerKm
    }
}

struct WorkoutSession: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let durationSeconds: TimeInterval
    let distanceMeters: Double
    let averagePaceSecondsPerKm: TimeInterval?
    let averageHR: Int?
    let maxHR: Int?
    let targetMinBPM: Int
    let targetMaxBPM: Int
    let zoneLabel: String
    let splits: [KilometerSplit]
    let route: [CoordinatePoint]
    let estimatedRecoveryHours: Int
    /// Calo dei battiti nel primo minuto post-corsa (Heart Rate Recovery 1 min), se misurato
    let hrr1MinDrop: Int?

    var distanceKm: Double {
        distanceMeters / 1000.0
    }
}

enum RecoveryEstimator {
    /// Stima il tempo di recupero consigliato (in ore) in base a durata, intensità cardiaca (% FC max)
    /// ed eventuale calo HRR a 1 minuto post-corsa.
    static func estimateRecoveryHours(
        durationSeconds: TimeInterval,
        averageHR: Int?,
        maxHRSetting: Int,
        hrr1MinDrop: Int? = nil
    ) -> Int {
        let minutes = durationSeconds / 60.0
        guard minutes >= 3 else { return 6 }

        let intensityRatio: Double
        if let avg = averageHR, maxHRSetting > 0 {
            intensityRatio = min(1.0, max(0.50, Double(avg) / Double(maxHRSetting)))
        } else {
            intensityRatio = 0.72
        }

        // Fattore carico cardiovascolare semplificato (ispirato a TRIMP)
        let zoneMultiplier: Double
        switch intensityRatio {
        case ..<0.65:
            zoneMultiplier = 0.28
        case 0.65..<0.75:
            zoneMultiplier = 0.48
        case 0.75..<0.85:
            zoneMultiplier = 0.75
        default:
            zoneMultiplier = 1.15
        }

        var hours = 8.0 + (minutes * zoneMultiplier)

        // Se è stato misurato il recupero a 1 minuto (HRR1):
        // > 30 bpm di calo indica ottimo recupero; < 18 bpm suggerisce più riposo
        if let drop = hrr1MinDrop {
            if drop >= 35 {
                hours *= 0.85
            } else if drop < 18 {
                hours *= 1.20
            }
        }

        let clamped = max(8, min(72, Int(hours.rounded())))
        return clamped
    }

    static func recoveryDescription(hours: Int) -> String {
        switch hours {
        case ..<18:
            return "Recupero leggero · puoi allenarti già domani"
        case 18..<30:
            return "Recupero moderato · consigliato 1 giorno tranquillo"
        case 30..<48:
            return "Carico impegnativo · consigliato riposo o corsa molto blanda"
        default:
            return "Carico elevato · riposo completo consigliato"
        }
    }
}
