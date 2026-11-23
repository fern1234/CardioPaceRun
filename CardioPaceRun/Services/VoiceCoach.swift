import Foundation
import AVFoundation

/// Guida vocale esclusivamente in italiano tramite cuffie/altoparlante.
/// Nessun bip sonoro e supporto completo anche a schermo bloccato.
@MainActor
final class VoiceCoach: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var italianVoice: AVSpeechSynthesisVoice?

    override init() {
        super.init()
        synthesizer.delegate = self
        italianVoice = Self.selectBestItalianVoice()
    }

    private static func selectBestItalianVoice() -> AVSpeechSynthesisVoice? {
        let italianVoices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.lowercased().hasPrefix("it")
        }
        if let enhanced = italianVoices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        return AVSpeechSynthesisVoice(language: "it-IT") ?? italianVoices.first
    }

    func configureAudioSessionForRun() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .voicePrompt,
                options: [.duckOthers, .mixWithOthers, .interruptSpokenAudioAndMixWithOthers]
            )
            try session.setActive(true)
        } catch {
            // In caso di errore di configurazione audio non blocca la corsa
        }
    }

    func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speak(_ text: String, interrupt: Bool = false) {
        configureAudioSessionForRun()

        if interrupt, synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = italianVoice ?? AVSpeechSynthesisVoice(language: "it-IT")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.98
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.08

        synthesizer.speak(utterance)
    }

    func announceRunStarted(targetRange: ClosedRange<Int>) {
        speak(
            "Corsa avviata. Mantieni i battiti tra \(targetRange.lowerBound) e \(targetRange.upperBound).",
            interrupt: true
        )
    }

    func announcePaused() {
        speak("Corsa in pausa.", interrupt: true)
    }

    func announceResumed() {
        speak("Corsa ripresa.", interrupt: true)
    }

    func announceFinished(distanceKm: Double, avgHR: Int?) {
        let kmText = String(format: "%.2f", distanceKm).replacingOccurrences(of: ".", with: " virgola ")
        if let avgHR {
            speak("Corsa terminata. Distanza \(kmText) chilometri. Battiti medi \(avgHR).", interrupt: true)
        } else {
            speak("Corsa terminata. Distanza \(kmText) chilometri.", interrupt: true)
        }
    }

    func announceTooFast(bpm: Int) {
        speak("Rallenta, battiti alti: \(bpm).", interrupt: true)
    }

    func announceCanGoFaster(bpm: Int) {
        speak("Puoi accelerare, battiti a \(bpm).", interrupt: true)
    }

    func announceKilometerSplit(
        kmIndex: Int,
        splitDuration: TimeInterval,
        averageHR: Int?,
        currentBPM: Int?,
        targetRange: ClosedRange<Int>
    ) {
        let spokenTime = RunFormatter.spokenDurationItalian(splitDuration)
        var message = "Chilometro \(kmIndex) completato. Tempo \(spokenTime)."

        if let avgHR = averageHR {
            message += " Battiti medi \(avgHR)."
        }

        if let bpm = currentBPM ?? averageHR {
            if bpm > targetRange.upperBound {
                message += " Rallenta, battiti alti."
            } else if bpm < targetRange.lowerBound {
                message += " Puoi accelerare."
            } else {
                message += " Battiti perfetti, mantieni questo ritmo."
            }
        }

        speak(message, interrupt: false)
    }
}

extension VoiceCoach: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Mantiene la sessione pronta durante la corsa senza interrompere la musica
    }
}
