import Foundation

enum RunFormatter {
    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    static func pace(_ secondsPerKm: TimeInterval?) -> String {
        guard let pace = secondsPerKm, pace.isFinite, pace > 0, pace < 3600 else {
            return "--:--"
        }
        let total = Int(pace.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    static func distanceKm(_ meters: Double) -> String {
        String(format: "%.2f", meters / 1000.0)
    }

    static func spokenDurationItalian(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let m = total / 60
        let s = total % 60

        var parts: [String] = []
        if m == 1 {
            parts.append("1 minuto")
        } else if m > 1 {
            parts.append("\(m) minuti")
        }

        if s == 1 {
            parts.append("1 secondo")
        } else if s > 1 || parts.isEmpty {
            parts.append("\(s) secondi")
        }

        return parts.joined(separator: " e ")
    }

    static func dateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
