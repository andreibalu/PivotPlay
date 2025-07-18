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
    @StateObject private var viewModel = WorkoutListViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                switch viewModel.state {
                case .loading:
                    LoadingView()
                case .loaded(let workouts):
                    if workouts.isEmpty {
                        EmptyWorkoutsView()
                    } else {
                        WorkoutListView(workouts: workouts, onDelete: deleteWorkouts)
                    }
                case .error(let error):
                    ErrorStateView(error: error, onRetry: viewModel.loadWorkouts)
                }
            }
            .navigationTitle("Latest Workouts")
            .refreshable {
                await viewModel.refreshWorkouts()
            }
        }
        .onAppear {
            viewModel.loadWorkouts()
        }
    }
    
    private func deleteWorkouts(offsets: IndexSet, workouts: [WorkoutSession]) {
        let workoutsToDelete = offsets.map { workouts[$0] }
        viewModel.deleteWorkouts(workoutsToDelete)
    }
}

// MARK: - View Model

@MainActor
class WorkoutListViewModel: ObservableObject {
    @Published var state: ViewState = .loading
    
    enum ViewState {
        case loading
        case loaded([WorkoutSession])
        case error(PivotPlayError)
    }
    
    func loadWorkouts() {
        state = .loading
        
        Task {
            // Add small delay to show loading state
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            let result = WorkoutStorage.shared.fetchWorkouts()
            
            await MainActor.run {
                switch result {
                case .success(let workouts):
                    state = .loaded(workouts)
                case .failure(let error):
                    state = .error(error)
                }
            }
        }
    }
    
    func refreshWorkouts() async {
        let result = WorkoutStorage.shared.fetchWorkouts()
        
        switch result {
        case .success(let workouts):
            state = .loaded(workouts)
        case .failure(let error):
            state = .error(error)
        }
    }
    
    func deleteWorkouts(_ workouts: [WorkoutSession]) {
        let result = WorkoutStorage.shared.deleteWorkouts(workouts)
        
        switch result {
        case .success:
            // Reload workouts after successful deletion
            loadWorkouts()
        case .failure(let error):
            state = .error(error)
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading workouts...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty State View

struct EmptyWorkoutsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.run")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No workouts yet")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("Start a workout on your Apple Watch to see your activity here.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "applewatch")
                        .foregroundColor(.blue)
                    Text("Open the PivotPlay app on your Watch")
                        .font(.caption)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "play.circle")
                        .foregroundColor(.green)
                    Text("Start a workout session")
                        .font(.caption)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.orange)
                    Text("Your workout will sync automatically")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let error: PivotPlayError
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: errorIcon)
                .font(.system(size: 64))
                .foregroundColor(.red)
            
            VStack(spacing: 12) {
                Text("Unable to Load Workouts")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                if let recoverySuggestion = error.recoverySuggestion {
                    Text(recoverySuggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                }
            }
            
            VStack(spacing: 12) {
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                
                if shouldShowStorageInfo {
                    Button("Storage Information") {
                        showStorageInfo()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var errorIcon: String {
        switch error {
        case .storageUnavailable, .storageInitializationFailed:
            return "externaldrive.trianglebadge.exclamationmark"
        case .networkTimeout, .watchConnectivityFailed:
            return "applewatch.slash"
        case .fetchFailed, .corruptData:
            return "exclamationmark.triangle"
        default:
            return "exclamationmark.circle"
        }
    }
    
    private var shouldShowStorageInfo: Bool {
        switch error {
        case .storageUnavailable, .storageInitializationFailed, .fetchFailed:
            return true
        default:
            return false
        }
    }
    
    private func showStorageInfo() {
        // This could show a detailed storage diagnostic view
        // For now, we'll just log the storage health check
        let isHealthy = WorkoutStorage.shared.checkStorageHealth()
        print("Storage health check: \(isHealthy)")
    }
}

// MARK: - Workout List View

struct WorkoutListView: View {
    let workouts: [WorkoutSession]
    let onDelete: (IndexSet, [WorkoutSession]) -> Void
    
    var body: some View {
        List {
            ForEach(workouts) { workout in
                NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                    WorkoutRowView(workout: workout)
                }
            }
            .onDelete { offsets in
                onDelete(offsets, workouts)
            }
        }
    }
}

// MARK: - Workout Row View

struct WorkoutRowView: View {
    let workout: WorkoutSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.date, style: .date)
                .font(.headline)
            
            HStack {
                Text(workout.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatDistance(workout.totalDistance))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(formatDuration(workout.duration))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if !workout.heartRateData.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text("\(Int(averageHeartRate)) BPM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var averageHeartRate: Double {
        guard !workout.heartRateData.isEmpty else { return 0 }
        let total = workout.heartRateData.reduce(0) { $0 + $1.value }
        return total / Double(workout.heartRateData.count)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        
        return formatter.string(from: duration) ?? "0s"
    }
    
    private func formatDistance(_ distance: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        let measurement = Measurement(value: distance, unit: UnitLength.meters)
        return formatter.string(from: measurement)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WorkoutSession.self, inMemory: true)
}
