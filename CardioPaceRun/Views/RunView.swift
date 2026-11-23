import SwiftUI

struct RunView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var heartRateManager: HeartRateManager
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var runManager: RunSessionManager

    @State private var showScannerSheet = false
    @State private var showStopConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                bluetoothBar

                RouteMapView(
                    routePoints: locationManager.routePoints,
                    followUser: true
                )
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )

                metricsGrid

                if let lastSplit = runManager.splits.last {
                    lastSplitBar(split: lastSplit)
                }

                controlButtons
            }
            .padding()
            .navigationTitle("Corsa")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                locationManager.startPreviewLocation()
            }
            .sheet(isPresented: $showScannerSheet) {
                BluetoothScannerSheet()
            }
            .sheet(item: $runManager.pendingSummary) { summary in
                PostRunSummaryView(summary: summary)
                    .interactiveDismissDisabled()
            }
            .confirmationDialog(
                "Terminare la corsa?",
                isPresented: $showStopConfirmation,
                titleVisibility: .visible
            ) {
                Button("Termina e vai al riepilogo", role: .destructive) {
                    runManager.stopRun()
                }
                Button("Continua a correre", role: .cancel) {}
            }
        }
    }

    private var bluetoothBar: some View {
        Button {
            showScannerSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: heartRateManager.connectionState.isConnected ? "heart.fill" : "dot.radiowaves.left.and.right")
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(heartRateManager.connectionState.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("Target: \(store.settings.targetRange.lowerBound)–\(store.settings.targetRange.upperBound) BPM (\(store.settings.activeLabel)) · Solo voce")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let battery = heartRateManager.batteryLevel {
                    Label("\(battery)%", systemImage: "battery.100")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// Griglia numerica neutra: nessuna indicazione visiva di accelerazione/rallentamento.
    /// Tutto il coaching su battiti alti/bassi avviene esclusivamente tramite voce in cuffia.
    private var metricsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            MetricTile(
                title: "Distanza",
                value: RunFormatter.distanceKm(locationManager.totalDistanceMeters),
                unit: "km"
            )
            MetricTile(
                title: "Tempo",
                value: RunFormatter.duration(runManager.elapsedSeconds),
                unit: ""
            )
            MetricTile(
                title: "Passo medio",
                value: RunFormatter.pace(runManager.averagePaceSecondsPerKm),
                unit: "min/km"
            )
            MetricTile(
                title: "Battiti",
                value: heartRateManager.currentBPM.map(String.init) ?? "--",
                unit: "BPM"
            )
        }
    }

    private func lastSplitBar(split: KilometerSplit) -> some View {
        HStack {
            Text("Ultimo km (#\(split.kilometerIndex))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("Tempo \(RunFormatter.duration(split.splitDurationSeconds))")
                .font(.caption.monospacedDigit())
            if let hr = split.averageHR {
                Text("· \(hr) BPM medi")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var controlButtons: some View {
        switch runManager.state {
        case .idle:
            Button {
                runManager.startRun()
            } label: {
                Label("Avvia corsa", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)

        case .running:
            HStack(spacing: 12) {
                Button {
                    runManager.pauseRun()
                } label: {
                    Label("Pausa", systemImage: "pause.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    showStopConfirmation = true
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
            }

        case .paused:
            HStack(spacing: 12) {
                Button {
                    runManager.resumeRun()
                } label: {
                    Label("Riprendi", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    showStopConfirmation = true
                } label: {
                    Label("Termina", systemImage: "stop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct BluetoothScannerSheet: View {
    @EnvironmentObject private var heartRateManager: HeartRateManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Stato connessione") {
                    HStack {
                        Text(heartRateManager.connectionState.label)
                        Spacer()
                        if let bpm = heartRateManager.currentBPM {
                            Text("\(bpm) BPM")
                                .font(.headline.monospacedDigit())
                        }
                    }

                    if heartRateManager.connectionState.isConnected {
                        Button("Disconnetti fascia", role: .destructive) {
                            heartRateManager.disconnect()
                        }
                    } else {
                        Button("Cerca fascia cardio (es. iGPSPORT HR50)") {
                            heartRateManager.startScan()
                        }
                    }
                }

                Section("Dispositivi trovati") {
                    if heartRateManager.discoveredDevices.isEmpty {
                        Text("Indossa la fascia cardio (inumidisci leggermente gli elettrodi) e premi Cerca.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(heartRateManager.discoveredDevices) { device in
                            Button {
                                heartRateManager.connect(to: device)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(device.name)
                                            .foregroundStyle(.primary)
                                        Text("Segnale: \(device.rssi) dBm")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("Collega")
                                        .font(.subheadline.weight(.medium))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fascia Cardio BLE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        heartRateManager.stopScan()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if !heartRateManager.connectionState.isConnected {
                    heartRateManager.startScan()
                }
            }
            .onDisappear {
                heartRateManager.stopScan()
            }
        }
    }
}

struct PostRunSummaryView: View {
    @EnvironmentObject private var heartRateManager: HeartRateManager
    @EnvironmentObject private var runManager: RunSessionManager

    let summary: WorkoutSession

    var body: some View {
        NavigationStack {
            List {
                if summary.route.count >= 2 {
                    Section("Percorso") {
                        RouteMapView(routePoints: summary.route, followUser: false)
                            .frame(height: 190)
                            .listRowInsets(EdgeInsets())
                    }
                }

                Section("Riepilogo corsa") {
                    LabeledContent("Distanza", value: "\(RunFormatter.distanceKm(summary.distanceMeters)) km")
                    LabeledContent("Tempo totale", value: RunFormatter.duration(summary.durationSeconds))
                    LabeledContent("Passo medio", value: "\(RunFormatter.pace(summary.averagePaceSecondsPerKm)) min/km")
                    LabeledContent("Battiti medi", value: summary.averageHR.map { "\($0) BPM" } ?? "--")
                    LabeledContent("Battiti massimi", value: summary.maxHR.map { "\($0) BPM" } ?? "--")
                    LabeledContent("Target", value: "\(summary.targetMinBPM)–\(summary.targetMaxBPM) BPM (\(summary.zoneLabel))")
                }

                Section("Tempo di recupero") {
                    LabeledContent("Recupero stimato", value: "\(summary.estimatedRecoveryHours) ore")
                    Text(RecoveryEstimator.recoveryDescription(hours: summary.estimatedRecoveryHours))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let drop = summary.hrr1MinDrop {
                        LabeledContent("Recupero FC (1 min)", value: "-\(drop) BPM")
                    } else if runManager.isMeasuringHRR {
                        HStack {
                            Text("Resta fermo con la fascia...")
                            Spacer()
                            Text("\(runManager.hrrRemainingSeconds)s")
                                .font(.headline.monospacedDigit())
                        }
                        Button("Annulla misurazione", role: .cancel) {
                            runManager.cancelHRRTest()
                        }
                    } else if heartRateManager.currentBPM != nil {
                        Button("Misura recupero FC (1 minuto)") {
                            runManager.startOneMinuteHRRTest()
                        }
                    }
                }

                if !summary.splits.isEmpty {
                    Section("Tempi per chilometro") {
                        ForEach(summary.splits) { split in
                            HStack {
                                Text("Km \(split.kilometerIndex)")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(RunFormatter.duration(split.splitDurationSeconds))
                                    .monospacedDigit()
                                if let avgHR = split.averageHR {
                                    Text("· \(avgHR) BPM")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        runManager.savePendingWorkout()
                    } label: {
                        Text("Salva corsa")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }

                    Button("Scarta corsa", role: .destructive) {
                        runManager.discardPendingWorkout()
                    }
                }
            }
            .navigationTitle("Corsa completata")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
