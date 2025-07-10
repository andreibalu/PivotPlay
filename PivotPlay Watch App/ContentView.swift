//
//  ContentView.swift
//  PivotPlay Watch App
//
//  Created by andrei on 10.07.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()

    var body: some View {
        VStack(spacing: 15) {
            if workoutManager.workoutState == .notStarted || workoutManager.workoutState == .ended {
                StartButton(
                    title: "Start Workout",
                    systemImage: "figure.soccer",
                    action: {
                        workoutManager.startWorkout()
                    }
                )
            } else {
                VStack(spacing: 12) {
                    LiveMetricView(label: "Duration", value: formatDuration(workoutManager.duration))
                    LiveMetricView(label: "Distance", value: String(format: "%.2f km", workoutManager.distance / 1000))
                    LiveMetricView(label: "Heart Rate", value: String(format: "%.0f BPM", workoutManager.heartRate))
                }
                
                StopButton(
                    title: "End Workout",
                    systemImage: "stop.circle.fill",
                    action: {
                        workoutManager.stopWorkout()
                    }
                )
            }
        }
        .onAppear {
            // Request permissions as soon as the view appears
            workoutManager.requestPermissions()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00:00"
    }
}

// MARK: - Reusable UI Components

struct StartButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle()) // Removes default button styling
    }
}

struct StopButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LiveMetricView: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}


#Preview {
    ContentView()
}
