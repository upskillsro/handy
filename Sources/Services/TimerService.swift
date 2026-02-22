import Foundation
import Combine
import SwiftUI
import UserNotifications

enum TimerState {
    case stopped
    case running
    case paused
}


// Decoupled Ticker to prevent main TimerService from invalidating views every second
@MainActor
class TimeTicker: ObservableObject {
    @Published var remainingTime: TimeInterval = 0
}

@MainActor
class TimerService: ObservableObject {
    @Published var activeReminderId: String? = nil
    @Published var state: TimerState = .stopped
    // @Published var remainingTime: TimeInterval = 0  <-- REMOVED
    @Published var isFocusMode: Bool = false // Tracks if we are in "Pill" mode
    @Published var initialDuration: TimeInterval = 0
    
    @Published var isOnBreak: Bool = false
    @Published var isOvertime: Bool = false // Tracks if we exceeded the estimated time
    @Published var timesUpTriggered: Bool = false
    @Published var taskAlertTriggered: Bool = false // Tracks if the periodic alert fired
    @Published var isStopwatch: Bool = false // Tracks if we are in stopwatch mode (counting up from 0)
    
    // Ticker Instance
    let ticker = TimeTicker()
    
    // Computed proxy for backward compatibility (non-reactive for TimerService observers)
    var remainingTime: TimeInterval {
        get { ticker.remainingTime }
        set { ticker.remainingTime = newValue }
    }
    
    // Cached Resources
    private var alertSound: NSSound?
    
    // Dependencies
    weak var estimateStore: EstimateStore?
    var settings = SettingsStore() // Direct instance for reading
    
    // Resume State
    private var savedTaskState: (id: String, duration: TimeInterval)?
    
    // Time Tracking Batching
    private var accumulatedTime: TimeInterval = 0
    private var timeSinceLastAlert: TimeInterval = 0 // Track periodic alerts
    private let flushInterval: TimeInterval = 5.0
    
    private var timer: AnyCancellable?
    private var lastTick: Date?
    
    init() {
        // Request Notification Perms once on launch
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { success, error in
                if let error = error {
                    print("Notification auth error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func startTimer(reminderId: String, duration: TimeInterval) {
        // Stop any break or previous timer
        stopTimer()
        
        activeReminderId = reminderId
        initialDuration = duration
        
        // Stopwatch Mode Check: If duration is 0, we treat it as no estimate -> Stopwatch
        if duration == 0 {
            isStopwatch = true
            
            // Resume stopwatch from previous accumulated time if exists, else 0
            let spent = estimateStore?.getMetadata(for: reminderId)?.timeSpent ?? 0
            remainingTime = spent // In stopwatch mode, remainingTime tracks CURRENT active duration (counting up)
            
            isOvertime = false
            timesUpTriggered = false
        } else {
            isStopwatch = false
            
            // Calculate remaining time based on previous progress
            let spent = estimateStore?.getMetadata(for: reminderId)?.timeSpent ?? 0
            let left = duration - spent
            
            if left > 0 {
                // Normal Resume
                remainingTime = left
                isOvertime = false
                timesUpTriggered = false
            } else {
                // Already in Overtime
                remainingTime = left // Will be negative or zero
                isOvertime = true
                timesUpTriggered = false 
            }
        }
        
        state = .running
        isOnBreak = false
        accumulatedTime = 0
        timeSinceLastAlert = 0
        startTicker()
    }
    func startBreak(duration: TimeInterval? = nil) { // Default from settings
        let breakLen = duration ?? settings.breakDuration
        if let activeId = activeReminderId {
            flushTimeSpent() // Save progress before break
            savedTaskState = (activeId, initialDuration)
        }
        
        // Transition directly to break
        timer?.cancel()
        
        isOnBreak = true
        activeReminderId = nil
        initialDuration = breakLen
        remainingTime = breakLen
        state = .running
        isOvertime = false
        timesUpTriggered = false
        timeSinceLastAlert = 0
        startTicker()
    }
    
    func endBreak() {
        guard isOnBreak else { return }
        
        // Capture state before stopping (which clears savedTaskState)
        let resumeState = savedTaskState
        
        stopTimer() // Clears break state and savedTaskState
        
        // Resume task if we have one saved
        if let saved = resumeState {
            // Reuse the smart startTimer logic (which calculates remaining from Estimate - PriorTimeSpent)
            // Since we flushed time spent before break, this will be accurate.
            startTimer(reminderId: saved.id, duration: saved.duration)
        }
    }
    
    func startOvertime() {
        timesUpTriggered = false
        isOvertime = true
        state = .running
        startTicker()
    }
    
    func pauseTimer() {
        guard state == .running else { return }
        flushTimeSpent()
        state = .paused
        timer?.cancel()
        timer = nil
        lastTick = nil
    }
    
    func resumeTimer() {
        // Resume if we have an active task OR if we are on break OR overtime
        guard state == .paused, (activeReminderId != nil || isOnBreak) else { return }
        state = .running
        startTicker()
    }
    
    func stopTimer() {
        flushTimeSpent()
        state = .stopped
        activeReminderId = nil
        isOnBreak = false
        isOvertime = false
        isStopwatch = false
        timesUpTriggered = false
        taskAlertTriggered = false
        savedTaskState = nil // Clear saved state on manual stop
        accumulatedTime = 0
        timeSinceLastAlert = 0
        timer?.cancel()
        timer = nil
        lastTick = nil
        remainingTime = 0
    }
    
    private func flushTimeSpent() {
        guard let id = activeReminderId, accumulatedTime > 0 else { return }
        estimateStore?.addTimeSpent(for: id, seconds: accumulatedTime)
        accumulatedTime = 0
    }

    private func startTicker() {
        lastTick = Date()
        
        lastTick = Date()
        
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    private func tick() {
        guard let last = lastTick else {
            lastTick = Date()
            return
        }
        
        let now = Date()
        let delta = now.timeIntervalSince(last)
        lastTick = now
        
        // Track actual time spent (if not on break)
        if (state == .running && !isOnBreak && activeReminderId != nil) {
            accumulatedTime += delta
            if accumulatedTime >= flushInterval {
                flushTimeSpent()
            }
            
            // Task Alerts Logic
            if settings.isTaskAlertEnabled {
                timeSinceLastAlert += delta
                if timeSinceLastAlert >= settings.taskAlertInterval {
                    triggerTaskAlert()
                    timeSinceLastAlert = 0
                }
            }
        }
        
        if isStopwatch {
            // Stopwatch Mode: Count UP
            remainingTime += delta
        } else if isOvertime {
            // Count UP (store as negative remaining time for easy calc, or just add?)
            // We'll calculate it as: remainingTime decreases into negatives
            remainingTime -= delta
        } else {
            // Normal Count Down
            if remainingTime > 0 {
                remainingTime -= delta
                if remainingTime <= 0 {
                    remainingTime = 0
                    handleTimesUp()
                }
            }
        }
    }
    
    // Trigger the periodic task alert (sound + animation)
    private func triggerTaskAlert() {
        // Play Sound
        if let sound = NSSound(named: settings.taskAlertSound) {
            sound.volume = Float(settings.taskAlertVolume)
            sound.play()
        }
        
        // Trigger Animation
        taskAlertTriggered = true
        
        // Reset animation state after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.taskAlertTriggered = false
        }
    }
    
    private func handleTimesUp() {
        if isOnBreak {
            // Auto-resume task if break ends
            NSSound.beep()
            endBreak()
            return
        }
        
        // Trigger Time's Up State for tasks
        timesUpTriggered = true
        timer?.cancel()
        timer = nil
        state = .paused
        // Play Sound
        // Play Sound
        if settings.isAlertEnabled {
            // Load/Reload sound if changed or not loaded
            if alertSound == nil || alertSound?.name != NSSound.Name(settings.alertSound) {
                 alertSound = NSSound(named: settings.alertSound)
            }
            
            if let sound = alertSound {
                sound.volume = Float(settings.alertVolume)
                sound.play()
            } else {
                NSSound.beep()
            }
        }
        
        sendNotification()
    }
    
    private func sendNotification() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Timer Finished"
        content.body = "Your focus session has ended."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // Helper format - Now static or using ticker if available, but for compatibility acts on current remainingTime
    func formattedTime() -> String {
        let val = isOvertime ? abs(remainingTime) : remainingTime
        let totalSeconds = Int(val)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        
        let prefix = isOvertime ? "+" : ""
        
        if h > 0 {
            return String(format: "%@%02d:%02d:%02d", prefix, h, m, s)
        } else {
            return String(format: "%@%02d:%02d", prefix, m, s)
        }
    }
}
