import SwiftUI

enum PanelPosition: String, CaseIterable {
    case left
    case right
}

class SettingsStore: ObservableObject {
    @AppStorage("panelPosition") var panelPosition: PanelPosition = .left
    @AppStorage("breakDuration") var breakDuration: Double = 300 // 5 minutes default
    
    // Alert Settings
    @AppStorage("isAlertEnabled") var isAlertEnabled: Bool = true
    @AppStorage("alertSound") var alertSound: String = "Glass"
    @AppStorage("alertVolume") var alertVolume: Double = 1.0
    
    // Task Alerts
    @AppStorage("isTaskAlertEnabled") var isTaskAlertEnabled: Bool = false
    @AppStorage("taskAlertInterval") var taskAlertInterval: Double = 600.0
    @AppStorage("taskAlertSound") var taskAlertSound: String = "Tink"
    @AppStorage("taskAlertVolume") var taskAlertVolume: Double = 0.5
    
    // Appearance
    @AppStorage("appTheme") var appTheme: AppTheme = .glass
}

enum AppTheme: String, CaseIterable {
    case glass
    case dark
}
