//
//  ContentView.swift
//  PivotPlay Watch App
//
//  Created by andrei on 10.07.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()
    @State private var scrollOffset: CGFloat = 0
    
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
                // Workout metrics at the top
                VStack(spacing: 12) {
                    LiveMetricView(label: "Duration", value: formatDuration(workoutManager.duration))
                    LiveMetricView(label: "Distance", value: String(format: "%.2f km", workoutManager.distance / 1000))
                    LiveMetricView(label: "Heart Rate", value: String(format: "%.0f BPM", workoutManager.heartRate))
                }
                
                // Swipe area with instruction and hidden stop button
                SwipeToStopView(
                    onStop: {
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

// MARK: - Swipe to Stop Component

struct SwipeToStopView: View {
    let onStop: () -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var isRevealed: Bool = false
    
    private let revealThreshold: CGFloat = 60
    private let maxDrag: CGFloat = 80
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Main instruction area
                HStack {
                    Image(systemName: "arrow.right")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("Swipe to Stop")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(width: geometry.size.width)
                .padding()
                .background(Color.black.opacity(0.1))
                .cornerRadius(10)
                
                // Stop button (hidden off-screen)
                StopButton(
                    title: "Stop",
                    systemImage: "stop.circle.fill",
                    action: {
                        onStop()
                        // Reset the swipe state
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dragOffset = 0
                            isRevealed = false
                        }
                    }
                )
                .frame(width: geometry.size.width * 0.8)
            }
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow rightward swipes (negative width translation)
                        let translation = min(0, value.translation.width)
                        dragOffset = max(-maxDrag, translation)
                        
                        // Update revealed state based on threshold
                        isRevealed = abs(dragOffset) > revealThreshold
                    }
                    .onEnded { value in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if isRevealed {
                                // Snap to revealed position
                                dragOffset = -maxDrag
                            } else {
                                // Snap back to hidden position
                                dragOffset = 0
                                isRevealed = false
                            }
                        }
                    }
            )
        }
        .frame(height: 60)
        .clipped() // Hide the overflow (stop button when not swiped)
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
