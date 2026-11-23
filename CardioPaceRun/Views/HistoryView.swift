import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: WorkoutStore

    var body: some View {
        NavigationStack {
            Group {
                if store.workouts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.run.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Nessuna corsa salvata")
                            .font(.headline)
                        Text("Le corse completate compariranno qui con mappa, tempi per km, media battiti e tempo di recupero.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        ForEach(store.workouts) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                WorkoutRow(workout: workout)
                            }
                        }
                        .onDelete(perform: store.deleteWorkouts)
                    }
                }
            }
            .navigationTitle("Cronologia")
        }
    }
}

private struct WorkoutRow: View {
    let workout: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(RunFormatter.dateShort(workout.date))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(RunFormatter.distanceKm(workout.distanceMeters)) km")
                    .font(.headline.monospacedDigit())
            }

            HStack(spacing: 14) {
                Label(RunFormatter.duration(workout.durationSeconds), systemImage: "timer")
                Label("\(RunFormatter.pace(workout.averagePaceSecondsPerKm))/km", systemImage: "speedometer")
                if let avgHR = workout.averageHR {
                    Label("\(avgHR) BPM", systemImage: "heart")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("Recupero consigliato: \(workout.estimatedRecoveryHours) ore · \(workout.zoneLabel)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
