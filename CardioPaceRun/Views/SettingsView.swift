import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var heartRateManager: HeartRateManager
    @EnvironmentObject private var voiceCoach: VoiceCoach

    @State private var showScannerSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Calcolo battiti target") {
                    Picker("Modalità", selection: $store.settings.mode) {
                        ForEach(HRTargetMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if store.settings.mode == .automatic {
                        Stepper(
                            "Età: \(store.settings.age) anni",
                            value: $store.settings.age,
                            in: 14...90
                        )

                        Toggle("Inserisci FC massima personalizzata", isOn: $store.settings.useCustomMaxHR)

                        if store.settings.useCustomMaxHR {
                            Stepper(
                                "FC massima: \(store.settings.customMaxHR) BPM",
                                value: $store.settings.customMaxHR,
                                in: 120...220
                            )
                        } else {
                            LabeledContent("FC massima stimata (220 - età)", value: "\(store.settings.effectiveMaxHR) BPM")
                        }

                        Picker("Zona di allenamento", selection: $store.settings.selectedZone) {
                            ForEach(TrainingZone.allCases) { zone in
                                Text(zone.rawValue).tag(zone)
                            }
                        }

                        Text(store.settings.selectedZone.subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Stepper(
                            "BPM minimo: \(store.settings.manualMinBPM)",
                            value: $store.settings.manualMinBPM,
                            in: 70...200
                        )
                        .onChange(of: store.settings.manualMinBPM) { newMin in
                            if store.settings.manualMaxBPM <= newMin + 2 {
                                store.settings.manualMaxBPM = min(220, newMin + 5)
                            }
                        }

                        Stepper(
                            "BPM massimo: \(store.settings.manualMaxBPM)",
                            value: $store.settings.manualMaxBPM,
                            in: 80...220
                        )
                        .onChange(of: store.settings.manualMaxBPM) { newMax in
                            if store.settings.manualMinBPM >= newMax - 2 {
                                store.settings.manualMinBPM = max(70, newMax - 5)
                            }
                        }
                    }

                    HStack {
                        Text("Intervallo attivo")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(store.settings.targetRange.lowerBound) – \(store.settings.targetRange.upperBound) BPM")
                            .font(.headline.monospacedDigit())
                    }
                }

                Section("Guida vocale in cuffia (solo voce, nessun bip)") {
                    Stepper(
                        "Intervallo avvisi fuori zona: \(store.settings.alertCooldownSeconds) s",
                        value: $store.settings.alertCooldownSeconds,
                        in: 10...90,
                        step: 5
                    )

                    Button("Prova voce guida in italiano") {
                        let range = store.settings.targetRange
                        voiceCoach.speak(
                            "Prova audio. Mantieni i battiti tra \(range.lowerBound) e \(range.upperBound). Rallenta, battiti alti. Puoi accelerare.",
                            interrupt: true
                        )
                    }
                }

                Section("Fascia cardio Bluetooth (iGPSPORT HR50)") {
                    LabeledContent("Stato", value: heartRateManager.connectionState.label)

                    if let bpm = heartRateManager.currentBPM {
                        LabeledContent("Battiti attuali", value: "\(bpm) BPM")
                    }
                    if let battery = heartRateManager.batteryLevel {
                        LabeledContent("Batteria fascia", value: "\(battery)%")
                    }

                    Button("Cerca / Collega fascia cardio") {
                        showScannerSheet = true
                    }

                    if heartRateManager.connectionState.isConnected {
                        Button("Dimentica fascia salvata", role: .destructive) {
                            heartRateManager.forgetSavedDevice()
                        }
                    }
                }
            }
            .navigationTitle("Impostazioni")
            .sheet(isPresented: $showScannerSheet) {
                BluetoothScannerSheet()
            }
        }
    }
}
