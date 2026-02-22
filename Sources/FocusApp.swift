import SwiftUI
import AppKit

@main
struct FocusApp: App {
    @StateObject var remindersService = RemindersService()
    @StateObject var estimateStore = EstimateStore()
    @StateObject var timerService = TimerService()
    @StateObject var windowCoordinator = AppWindowCoordinator()
    @State private var panelPositionObserver: NSObjectProtocol?
    
    init() {
        // Link services
        // We can't do this easily in init because of @StateObject lazy init order, 
        // but we can do it in onAppear or by passing it.
        // However, accessing the underlying objects of StateObject in init is tricky.
        // Let's rely on .onAppear or a separate setup method.
    }

    var body: some Scene {
        WindowGroup("Focus") {
            SideStripView()
                .environmentObject(remindersService)
                .environmentObject(timerService)
                .environmentObject(estimateStore)
                .environmentObject(windowCoordinator)
                .frame(minWidth: 300, maxWidth: 350)
                .onAppear {
                    // Set App Icon
                    if let iconUrl = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
                       let iconImage = NSImage(contentsOf: iconUrl) {
                        NSApplication.shared.applicationIconImage = iconImage
                    }
                    
                    // Link Dependencies
                    timerService.estimateStore = estimateStore
                    
                    // Ensure Dock icon
                    NSApp.setActivationPolicy(.regular)
                    
                    // Position Main Window as Sidebar
                    DispatchQueue.main.async {
                        if let window = NSApplication.shared.windows.first {
                            window.identifier = AppWindowCoordinator.mainWindowIdentifier
                            windowCoordinator.mainWindow = window
                            setupWindowPosition(window)
                            
                            // Observe position changes once per lifecycle
                            if panelPositionObserver == nil {
                                panelPositionObserver = NotificationCenter.default.addObserver(
                                    forName: NSNotification.Name("UpdatePanelPosition"),
                                    object: nil,
                                    queue: .main
                                ) { _ in
                                    withAnimation {
                                        setupWindowPosition(window)
                                    }
                                }
                            }
                        }
                    }
                }
                .onDisappear {
                    if let observer = panelPositionObserver {
                        NotificationCenter.default.removeObserver(observer)
                        panelPositionObserver = nil
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 350, height: 800)
        
        // Floating Pill - Single Instance Window
        Window("Timer", id: "timer-pill") {
            if timerService.isFocusMode && (timerService.activeReminderId != nil || timerService.isOnBreak) {
                FloatingPillView()
                    .environmentObject(timerService)
                    .environmentObject(remindersService)
                    .environmentObject(estimateStore)
                    .environmentObject(windowCoordinator)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        Settings {
            SettingsView()
        }
    }
    
    func setupWindowPosition(_ window: NSWindow) {
        let settings = SettingsStore() // Read purely for positioning
        
        window.level = .floating // Stay on top
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        if let screen = window.screen {
            let visibleFrame = screen.visibleFrame
            let width = window.frame.width
            let margin: CGFloat = 15
            let x: CGFloat = settings.panelPosition == .left ? visibleFrame.minX + margin : visibleFrame.maxX - width - margin
            
            let newFrame = NSRect(
                x: x,
                y: visibleFrame.minY + margin,
                width: width,
                height: visibleFrame.height - (margin * 2)
            )
            window.setFrame(newFrame, display: true)
        }
        
        // Visuals
        window.backgroundColor = .clear
        window.isOpaque = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovable = false // Lock position
    }
}
