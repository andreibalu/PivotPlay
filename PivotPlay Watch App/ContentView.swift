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

struct MiniFootballFieldView: View {
    let markedCorners: Int
    private let fieldColor = Color.green.opacity(0.2)
    private let markerColor = Color.blue
    private let markedColor = Color.green
    private let size: CGFloat = 80
    
    var body: some View {
        ZStack {
            // Field rectangle
            RoundedRectangle(cornerRadius: 8)
                .fill(fieldColor)
                .frame(width: size, height: size * 0.6)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 2)
                )
            // Corner markers
            ForEach(0..<4) { idx in
                Circle()
                    .fill(idx < markedCorners ? markedColor : markerColor)
                    .frame(width: 10, height: 10)
                    .position(position(for: idx))
                    .overlay(
                        Text("\(idx+1)")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: size, height: size * 0.6)
    }
    // Corner positions: 0=BL, 1=BR, 2=TR, 3=TL
    private func position(for idx: Int) -> CGPoint {
        let w = size
        let h = size * 0.6
        switch idx {
        case 0: return CGPoint(x: 0, y: h) // Bottom Left
        case 1: return CGPoint(x: w, y: h) // Bottom Right
        case 2: return CGPoint(x: w, y: 0) // Top Right
        case 3: return CGPoint(x: 0, y: 0) // Top Left
        default: return .zero
        }
    }
}

struct CornerCaptureView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @State private var currentCorner = 0
    @State private var validationFailed = false
    @State private var showLocationError = false
    @Environment(\.dismiss) private var dismiss
    
    private let cornerNames = ["Bottom Left", "Bottom Right", "Top Right", "Top Left"]
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress indicator
            VStack(spacing: 2) {
                Image(systemName: "location.circle")
                    .font(.title3)
                    .foregroundColor(.blue)
                Text("Pitch Setup")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(currentCorner)/4 corners marked")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            // Mini field with corner markers
            MiniFootballFieldView(markedCorners: currentCorner)
                .padding(.vertical, 4)
            if currentCorner < 4 {
                // Visual instruction: highlight which corner to mark
                Text("Tap when at corner \(currentCorner+1)")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 2)
                // Button to mark corner
                Button(action: {
                    if workoutManager.markCurrentCorner() {
                        currentCorner += 1
                        if currentCorner == 4 {
                            if workoutManager.validateCorners() {
                                // All good
                            } else {
                                validationFailed = true
                                workoutManager.resetCorners()
                                currentCorner = 0
                            }
                        }
                    } else {
                        showLocationError = true
                    }
                }) {
                    Text("Mark Corner \(currentCorner+1)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // All corners captured
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    Text("Pitch Saved!")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Start workout")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    StartButton(
                        title: "Start",
                        systemImage: "play.circle.fill",
                        action: {
                            workoutManager.startWorkout()
                            dismiss()
                        }
                    )
                }
            }
        }
        .padding(8)
        .navigationBarHidden(true)
        .onAppear {
            workoutManager.startCornerCapture()
        }
        .alert("Location Error", isPresented: $showLocationError) {
            Button("OK") { }
        } message: {
            Text("No location available. Please ensure GPS is active and try again.")
        }
        .alert("Invalid Corners", isPresented: $validationFailed) {
            Button("Retry") { }
        } message: {
            Text("Invalid corner points detected. Please retry corner capture.")
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
