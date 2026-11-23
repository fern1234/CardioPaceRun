import SwiftUI

struct WorkoutDetailView: View {
    let workout: WorkoutSession

    var body: some View {
        List {
            if workout.route.count >= 2 {
                Section("Tragitto GPS") {
                    RouteMapView(routePoints: workout.route, followUser: false)
                        .frame(height: 220)
                        .listRowInsets(EdgeInsets())
                }
            }

            Section("Medie totali") {
                LabeledContent("Data", value: RunFormatter.dateShort(workout.date))
                LabeledContent("Distanza", value: "\(RunFormatter.distanceKm(workout.distanceMeters)) km")
                LabeledContent("Tempo totale", value: RunFormatter.duration(workout.durationSeconds))
                LabeledContent("Passo medio", value: "\(RunFormatter.pace(workout.averagePaceSecondsPerKm)) min/km")
                LabeledContent("Media battiti", value: workout.averageHR.map { "\($0) BPM" } ?? "--")
                LabeledContent("Battiti massimi", value: workout.maxHR.map { "\($0) BPM" } ?? "--")
                LabeledContent("Fascia target", value: "\(workout.targetMinBPM)–\(workout.targetMaxBPM) BPM (\(workout.zoneLabel))")
            }

            Section("Recupero") {
                LabeledContent("Tempo di recupero stimato", value: "\(workout.estimatedRecoveryHours) ore")
                if let drop = workout.hrr1MinDrop {
                    LabeledContent("Calo FC in 1 minuto (HRR)", value: "-\(drop) BPM")
                }
                Text(RecoveryEstimator.recoveryDescription(hours: workout.estimatedRecoveryHours))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Parziali ogni 1 km") {
                if workout.splits.isEmpty {
                    Text("Corsa inferiore a 1 km: nessun parziale chilometrico registrato.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workout.splits) { split in
                        HStack {
                            Text("Km \(split.kilometerIndex)")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(RunFormatter.duration(split.splitDurationSeconds))
                                .monospacedDigit()
                            Text("· \(RunFormatter.pace(split.paceSecondsPerKm))/km")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            if let hr = split.averageHR {
                                Text("· \(hr) BPM")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Dettaglio corsa")
        .navigationBarTitleDisplayMode(.inline)
    }
}
