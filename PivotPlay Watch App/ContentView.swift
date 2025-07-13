//
//  ContentView.swift
//  PivotPlay Watch App
//
//  Created by andrei on 10.07.2025.
//

import SwiftUI
import HealthKit
import CoreLocation

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if workoutManager.workoutState == HKWorkoutSessionState.notStarted || workoutManager.workoutState == HKWorkoutSessionState.ended {
                        StartButton(
                            title: "Start Workout",
                            systemImage: "figure.soccer",
                            action: {
                                workoutManager.initiateWorkout()
                            }
                        )
                    } else {
                        // Workout status indicator
                        VStack(spacing: 8) {
                            Image(systemName: "figure.soccer")
                                .font(.title2)
                                .foregroundColor(.green)
                            Text("Workout Active")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .padding(.top, 10)
                        
                        // Live metrics with more spacing
                        VStack(spacing: 20) {
                            LiveMetricView(label: "Duration", value: formatDuration(workoutManager.duration))
                            LiveMetricView(label: "Distance", value: String(format: "%.2f km", workoutManager.distance / 1000))
                            LiveMetricView(label: "Heart Rate", value: String(format: "%.0f BPM", workoutManager.heartRate))
                        }
                        .padding(.vertical, 15)
                        
                        // Visual separator and hint to scroll
                        VStack(spacing: 8) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                            
                            HStack {
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("Scroll to stop")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 10)
                        
                        // Additional spacer to ensure scrolling is required
                        Spacer()
                            .frame(height: 60)
                        
                        // Stop button - requires scrolling to reach
                        StopButton(
                            title: "End Workout",
                            systemImage: "stop.circle.fill",
                            action: {
                                workoutManager.stopWorkout()
                            }
                        )
                        .padding(.bottom, 20)
                    }
                }
                .padding(.horizontal)
            }
            .navigationDestination(isPresented: $workoutManager.showingCornerCapture) {
                CornerCaptureView(workoutManager: workoutManager)
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

// MARK: - Corner Capture View

struct CornerCaptureView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @State private var currentCorner = 0
    @Environment(\.dismiss) private var dismiss
    
    private let cornerNames = ["Bottom Left", "Bottom Right", "Top Right", "Top Left"]
    
    var body: some View {
        VStack(spacing: 15) { // Reduced spacing
            // Progress indicator
            VStack(spacing: 5) { // Reduced spacing
                Image(systemName: "location.circle")
                    .font(.title2) // Slightly smaller
                    .foregroundColor(.blue)
                
                Text("Pitch Setup")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("\(currentCorner)/4 corners marked")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if currentCorner < 4 {
                // Instructions for current corner
                VStack(spacing: 8) { // Reduced spacing
                    Text("Walk to the")
                        .font(.body) // Smaller font
                    
                    Text(cornerNames[currentCorner])
                        .font(.headline) // Smaller font
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("corner and tap the button")
                        .font(.body) // Smaller font
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                
                Spacer()
                
                // Button to mark corner
                Button(action: {
                    workoutManager.markCurrentCorner()
                    currentCorner += 1
                }) {
                    Text("Mark Corner \(currentCorner + 1)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())

            } else {
                // All corners captured
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Pitch Saved!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Tap to start workout")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    StartButton(
                        title: "Start Workout",
                        systemImage: "play.circle.fill",
                        action: {
                            workoutManager.startWorkout()
                            dismiss()
                        }
                    )
                }
            }
        }
        .padding()
        .navigationBarHidden(true)
        .onAppear {
            workoutManager.startCornerCapture()
        }
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
        VStack(spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}
