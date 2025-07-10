
import Foundation
import SwiftData

#if os(iOS)
@MainActor
class WorkoutStorage {
    static let shared = WorkoutStorage()
    private let container: ModelContainer
    private let context: ModelContext

    private init() {
        do {
            let fullSchema = Schema([WorkoutSession.self])
            container = try ModelContainer(for: fullSchema, configurations: [])
            context = ModelContext(container)
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error.localizedDescription)")
        }
    }

    func saveWorkout(_ workout: WorkoutSession) {
        context.insert(workout)
        do {
            try context.save()
        } catch {
            print("Failed to save workout: \(error.localizedDescription)")
        }
    }

    func fetchWorkouts() -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch workouts: \(error.localizedDescription)")
            return []
        }
    }
    
    func deleteWorkout(_ workout: WorkoutSession) {
        context.delete(workout)
        do {
            try context.save()
        } catch {
            print("Failed to delete workout: \(error.localizedDescription)")
        }
    }
    
    func deleteWorkouts(_ workouts: [WorkoutSession]) {
        for workout in workouts {
            context.delete(workout)
        }
        do {
            try context.save()
        } catch {
            print("Failed to delete workouts: \(error.localizedDescription)")
        }
    }
}
#endif
