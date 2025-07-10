//
//  ContentView.swift
//  PivotPlay
//
//  Created by andrei on 10.07.2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workouts: [WorkoutSession]

    var body: some View {
        NavigationView {
            List(workouts) { workout in
                NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                    VStack(alignment: .leading) {
                        Text(workout.date, style: .date)
                            .font(.headline)
                        Text(String(format: "%.2f minutes", workout.duration / 60))
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Workouts")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WorkoutSession.self, inMemory: true)
}
