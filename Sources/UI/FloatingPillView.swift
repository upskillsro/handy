import SwiftUI

// MarqueeText removed in favor of static multi-line text for 0% CPU usage



// Helper to get NSWindow securely
struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct FloatingPillView: View {
    @EnvironmentObject var timerService: TimerService
    @EnvironmentObject var remindersService: RemindersService
    @EnvironmentObject var estimateStore: EstimateStore
    
    @State private var isHovering = false
    @State private var window: NSWindow?
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            if isHovering {
                PillControlsView(
                    isHovering: $isHovering,
                    timerService: timerService,
                    remindersService: remindersService,
                    estimateStore: estimateStore
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            } else {
                PillInfoView(
                    timerService: timerService,
                    remindersService: remindersService
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .frame(minWidth: 280, minHeight: 42) // Enforce minimum dimensions
        .fixedSize(horizontal: true, vertical: true) // Prevent shrinking below content
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
        .background(
            ZStack(alignment: .bottom) {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.3)
                
                // Pulse Effect for Time's Up
                if timerService.timesUpTriggered {
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .background(Color.red.opacity(0.1))
                        .opacity(isPulsing ? 1.0 : 0.0)
                        .animation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                        .onAppear { isPulsing = true }
                        .onDisappear { isPulsing = false }
                }
                
                // Pulse Effect for Task Alerts (Periodic)
                if timerService.taskAlertTriggered {
                     RoundedRectangle(cornerRadius: 30)
                         .stroke(Color.cyan.opacity(0.8), lineWidth: 2)
                         .background(Color.cyan.opacity(0.15))
                         .opacity(isPulsing ? 1.0 : 0.0)
                         .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
                         .onAppear { isPulsing = true }
                         .onDisappear { isPulsing = false }
                 }
                
                WindowAccessor(window: $window)
                
                // Bottom Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 3)
                        
                        Rectangle()
                            .fill(progressBarColor)
                            .frame(width: geo.size.width * CGFloat(progress), height: 3)
                            .shadow(color: progressBarColor.opacity(0.8), radius: 4, x: 0, y: 0)
                    }
                }
                .frame(height: 3)
            }
        )
        .cornerRadius(30)
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .preferredColorScheme(.dark)
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hover
            }
        }
        .onAppear {
              if let window = NSApp.windows.first(where: { $0.title == "Timer" }) {
                  styleWindow(window)
              }
        }
        .onChange(of: window) { _, newWindow in
            if let win = newWindow {
                styleWindow(win)
            }
        }
    }
    
    private func styleWindow(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        
        // Disable resizing strictly
        if window.styleMask.contains(.resizable) {
            window.styleMask.remove(.resizable)
        }
        
        // Hide standard buttons explicitly
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Ensure floating level
        window.level = .floating
        
        // Enable native dragging via background
        window.isMovableByWindowBackground = true
        window.isMovable = true
    }
    
    // Logic for Progress Bar
    private var progress: Double {
        if timerService.isOnBreak {
            let total = timerService.initialDuration
            let remaining = timerService.remainingTime
            let elapsed = total - remaining
            return total > 0 ? min(max(elapsed / total, 0.0), 1.0) : 0.0
        } else if let activeId = timerService.activeReminderId,
                  let _ = remindersService.reminders.first(where: { $0.calendarItemIdentifier == activeId }) {
            let duration = estimateStore.getMetadata(for: activeId)?.estimatedDuration ?? 1800
            let elapsed = estimateStore.getMetadata(for: activeId)?.timeSpent ?? 0
            return duration > 0 ? min(elapsed / duration, 1.0) : 0.0
        }
        return 0.0
    }
    
    private var progressBarColor: Color {
        return timerService.isOnBreak ? .orange : .green
    }
}

// MARK: - Subviews

struct PillControlsView: View {
    @Binding var isHovering: Bool
    @ObservedObject var timerService: TimerService
    @ObservedObject var remindersService: RemindersService
    @ObservedObject var estimateStore: EstimateStore
    
    var body: some View {
        HStack(spacing: 12) { // Reduced spacing slightly to fit larger touch targets
            
            // EXIT FOCUS (Red)
            ControlButton(color: .red, icon: "xmark", help: "Exit Focus Mode") {
                timerService.isFocusMode = false
            }
            
            // PAUSE/RESUME (Yellow)
            ControlButton(
                color: .yellow,
                icon: timerService.state == .running ? "pause.fill" : "play.fill",
                help: timerService.state == .running ? "Pause" : "Resume"
            ) {
                if timerService.state == .running {
                    timerService.pauseTimer()
                } else {
                    timerService.resumeTimer()
                }
            }
            
            // COMPLETE / END BREAK (Green)
            if let activeId = timerService.activeReminderId,
               let task = remindersService.reminders.first(where: { $0.calendarItemIdentifier == activeId }) {
                ControlButton(color: .green, icon: "checkmark", help: "Complete Task") {
                    remindersService.toggleComplete(task)
                    timerService.stopTimer()
                }
            } else if timerService.isOnBreak {
                ControlButton(color: .green, icon: "checkmark", help: "End Break") {
                    timerService.endBreak()
                    timerService.isFocusMode = false
                }
            }
            
            Divider().frame(height: 16).background(Color.white.opacity(0.2))
            
            // EXTEND TIME
            if timerService.timesUpTriggered {
                IconButton(icon: "clock.arrow.circlepath", color: .orange, help: "Extend Time") {
                    timerService.startOvertime()
                }
            }
            
            // SKIP / NEXT
            if timerService.isOnBreak {
                IconButton(icon: "forward.end.fill", color: .secondary, help: "Skip Break") {
                    timerService.endBreak()
                }
            } else {
                IconButton(icon: "forward.end.fill", color: .secondary, help: "Skip Task") {
                     if let activeId = timerService.activeReminderId,
                        let next = remindersService.getNextTask(after: activeId) {
                         let dur = estimateStore.getMetadata(for: next.calendarItemIdentifier)?.estimatedDuration ?? 1500
                         timerService.startTimer(reminderId: next.calendarItemIdentifier, duration: dur)
                     } else {
                         timerService.stopTimer()
                     }
                }
            }
            
            // BREAK / LIST
            if !timerService.isOnBreak {
                IconButton(icon: "cup.and.saucer.fill", color: .secondary, help: "Take a Break") {
                    timerService.startBreak(duration: 600)
                }
            } else {
                IconButton(icon: "square.grid.2x2", color: .secondary, help: "Open List") {
                    timerService.isFocusMode = false
                }
            }
        }
    }
}

struct PillInfoView: View {
    @ObservedObject var timerService: TimerService
    @ObservedObject var remindersService: RemindersService
    
    var body: some View {
        if timerService.isOnBreak {
            HStack(alignment: .center, spacing: 12) {
                Text("Break")
                    .font(.body).fontWeight(.bold)
                    .frame(maxWidth: 180)
                
                Divider().frame(height: 16).background(Color.white.opacity(0.2))
                
                PillTimerDisplay(ticker: timerService.ticker, service: timerService)
            }
        } else if let activeId = timerService.activeReminderId,
                  let activeTask = remindersService.reminders.first(where: { $0.calendarItemIdentifier == activeId }) {
            
            HStack(alignment: .center, spacing: 12) {
                // Use Equatable view to prevent redraws on timer tick
                PillTitleView(title: activeTask.title)
                    .equatable()
                    .frame(maxWidth: 180)
                
                Divider().frame(height: 16).background(Color.white.opacity(0.2))
                
                if timerService.timesUpTriggered {
                    Text("Time's Up")
                        .font(.headline).fontWeight(.bold)
                        .foregroundColor(.red)
                        .fixedSize()
                } else {
                    PillTimerDisplay(ticker: timerService.ticker, service: timerService)
                }
            }
        } else {
            Text("No Active Task").font(.body)
        }
    }
}

// Optimization: Equatable wrapper to stop redraws from TimerService updates
struct PillTitleView: View, Equatable {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.body)
            .fontWeight(.medium)
            .lineLimit(2) // Allow wrapping up to 2 lines
            .fixedSize(horizontal: false, vertical: true) // Allow growing vertically
            .multilineTextAlignment(.leading)
    }
    
    static func == (lhs: PillTitleView, rhs: PillTitleView) -> Bool {
        return lhs.title == rhs.title
    }
}

// Reusable Components
struct ControlButton: View {
    let color: Color
    let icon: String
    let help: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Color.clear.frame(width: 24, height: 24) // Enlarged touch target
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.black.opacity(0.6))
                    )
            }
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct IconButton: View {
    let icon: String
    let color: Color
    let help: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Color.clear.frame(width: 24, height: 24) // Enlarged touch target
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct PillTimerDisplay: View {
    @ObservedObject var ticker: TimeTicker
    @ObservedObject var service: TimerService
    
    var body: some View {
        Text(service.formattedTime())
            .font(.title2).fontWeight(.bold).monospacedDigit()
            .foregroundColor(service.isOvertime ? .orange : .white)
            .contentTransition(.numericText(countsDown: !service.isStopwatch && !service.isOvertime))
            .animation(.snappy, value: service.formattedTime())
            .fixedSize()
    }
}
