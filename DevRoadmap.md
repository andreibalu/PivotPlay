# Build Setup

- **iOS App:**
  - Scheme: `PivotPlay`
  - Simulator: `Iph16+watch10` (ID: 7F8FDE71-03D1-4061-9A4C-B066855786E6)
- **watchOS App:**
  - Scheme: `PivotPlay Watch App`
  - Simulator: `Apple Watch Series 10 (46mm)` (ID: 36AE1D63-0563-4F4A-9F6A-7525C4BF40FD)

Use these schemes and simulators for all builds. See BUILD_NOTES.md for command details.

### **PivotPlay MVP Roadmap**

This roadmap outlines the core milestones to build a functional Minimum Viable Product (MVP) for the PivotPlay app, focusing on the essential features for both the watchOS and iOS platforms.

---

#### **Phase 1: Foundation & Data Modeling (Complete)**

*   **Goal:** Set up the project structure and define the data that will be shared between the watch and the iPhone.
*   **Key Tasks:**
    1.  **Shared Data Model:** Create a `WorkoutSession` data structure. This will be the "container" for all the data your app tracks:
        *   `id`: A unique identifier for the workout.
        *   `date`: The start time of the workout.
        *   `duration`: The total length of the workout.
        *   `totalDistance`: The total distance covered.
        *   `heartRateData`: A list of heart rate measurements with timestamps.
        *   `locationData`: A list of GPS coordinates recorded during the session.
    2.  **Project Setup:** Ensure the Xcode project is correctly configured with targets for both the iOS and watchOS apps.

---

#### **Phase 2: watchOS App - The Recorder (Complete)**

*   **Goal:** Build the core workout recording functionality on the Apple Watch.
*   **Key Tasks:**
    1.  **UI:** Design a simple interface with "Start," "Stop," and a live view showing `Duration`, `Heart Rate`, and `Distance`.
    2.  **HealthKit Integration:**
        *   Request user permission to access health data (Heart Rate, Workout data).
        *   Use `HKWorkoutSession` to manage the soccer workout, which allows the app to run in the background and collect data efficiently.
    3.  **Location Tracking (CoreLocation):**
        *   Request user permission for "When in Use" location access.
        *   Continuously record the user's GPS coordinates during the workout session.
    4.  **Data Packaging:** When the user stops the workout, gather all the tracked data into the `WorkoutSession` model created in Phase 1.
    5.  **Heatmap Corner Capture Improvement:** Marking pitch corners for the heatmap is now done by tapping a button on the watch (instead of using the Digital Crown), and the instructional UI uses smaller fonts for better visibility.

---

#### **Phase 3: iPhone App - The Viewer (Complete)**

*   **Goal:** Create the iPhone app to display workout history and the heatmap.
*   **Key Tasks:**
    1.  **Workout List UI:**
        *   Create a main screen that displays a simple, scrollable list of all completed workouts.
        *   Each item in the list should show basic info, like the date and duration of the workout.
    2.  **Data Persistence:** Use **SwiftData** or **Core Data** to store the `WorkoutSession` objects received from the watch.
    3.  **Heatmap Detail View:**
        *   Create a detail screen that is shown when a user taps a workout from the list.
        *   Integrate **MapKit** to display a map.
        *   Develop the logic to render the `locationData` from the selected workout as a heatmap overlay on the map.
        *   The heatmap overlay now uses pitch corners marked by button tap for improved usability.

---

#### **Phase 4: Watch-to-iPhone Communication (Complete)**

*   **Goal:** Reliably transfer workout data from the watch to the phone.
*   **Key Tasks:**
    1.  **WatchConnectivity Framework:** Integrate the `WatchConnectivity` framework into both the watchOS and iOS apps.
    2.  **Data Transfer:**
        *   After a workout is completed on the watch, use `WCSession`'s `transferUserInfo` method to send the `WorkoutSession` data to the iPhone. This method is robust and works even if the iPhone app is in the background.
    3.  **Data Reception:**
        *   Implement the `WCSessionDelegate` on the iPhone to receive the data package from the watch.
        *   On receipt, decode the data and save it to the iPhone's persistent storage (from Phase 3). The workout list should then automatically update to show the new session.

---

#### **Phase 5: Testing & Polish**

*   **Goal:** Ensure the app is stable, reliable, and ready for initial users.
*   **Key Tasks:**
    1.  **End-to-End Testing:** Test the complete user flow on physical devices: start a workout on the watch, end it, and verify it appears correctly on the iPhone with a functional heatmap.
    2.  **Error Handling:** Add basic error handling (e.g., what happens if the user denies HealthKit or location permissions?).
    3.  **Refine UI/UX:** Polish the user interface and ensure the experience is smooth and intuitive. (Note: The heatmap corner marking process now uses a button for improved reliability and smaller fonts for clarity.)
