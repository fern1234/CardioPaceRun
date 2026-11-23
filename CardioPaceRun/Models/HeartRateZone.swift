import Foundation

enum TrainingZone: String, CaseIterable, Codable, Identifiable {
    case light = "Corsa leggera"
    case aerobic = "Aerobica"
    case threshold = "Soglia"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .light:
            return "60% – 70% FC max · Fondo lento e recupero"
        case .aerobic:
            return "70% – 80% FC max · Resistenza aerobica"
        case .threshold:
            return "80% – 90% FC max · Ritmo sostenuto / soglia"
        }
    }

    var percentageRange: ClosedRange<Double> {
        switch self {
        case .light:
            return 0.60...0.70
        case .aerobic:
            return 0.70...0.80
        case .threshold:
            return 0.80...0.90
        }
    }
}

enum HRTargetMode: String, CaseIterable, Codable, Identifiable {
    case automatic = "Automatico"
    case manual = "Manuale"

    var id: String { rawValue }
}

struct UserHRSettings: Codable, Equatable {
    var mode: HRTargetMode = .automatic
    var age: Int = 35
    var useCustomMaxHR: Bool = false
    var customMaxHR: Int = 185
    var selectedZone: TrainingZone = .aerobic

    var manualMinBPM: Int = 135
    var manualMaxBPM: Int = 155

    /// Secondi minimi tra due avvisi vocali consecutivi quando si resta fuori zona
    var alertCooldownSeconds: Int = 25

    var effectiveMaxHR: Int {
        if useCustomMaxHR {
            return max(120, min(220, customMaxHR))
        }
        return max(120, min(220, 220 - age))
    }

    var targetRange: ClosedRange<Int> {
        switch mode {
        case .automatic:
            let maxHR = Double(effectiveMaxHR)
            let low = Int((maxHR * selectedZone.percentageRange.lowerBound).rounded())
            let high = Int((maxHR * selectedZone.percentageRange.upperBound).rounded())
            return min(low, high)...max(low, high)
        case .manual:
            let low = max(60, min(210, manualMinBPM))
            let high = max(low + 2, min(220, manualMaxBPM))
            return low...high
        }
    }

    var activeLabel: String {
        switch mode {
        case .automatic:
            return selectedZone.rawValue
        case .manual:
            return "Manuale (\(targetRange.lowerBound)–\(targetRange.upperBound) BPM)"
        }
    }
}
