//
//  PivotPlayApp.swift
//  PivotPlay
//
//  Created by andrei on 10.07.2025.
//

import SwiftUI
import SwiftData

@main
struct PivotPlayApp: App {
    
    init() {
        _ = WatchConnectivityManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: WorkoutSession.self)
    }
}
