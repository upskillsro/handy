import SwiftUI

struct EmbeddedSettingsView: View {
    @ObservedObject var settings: SettingsStore
    var onClose: () -> Void
    
    let sounds = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.black.opacity(0.2))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    
                    // APPEARANCE
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Appearance")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            ThemePreviewCard(theme: .glass, isSelected: settings.appTheme == .glass) {
                                settings.appTheme = .glass
                            }
                            
                            ThemePreviewCard(theme: .dark, isSelected: settings.appTheme == .dark) {
                                settings.appTheme = .dark
                            }
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // PANEL POSITION
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Panel Position")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            PositionPreviewCard(position: .left, isSelected: settings.panelPosition == .left) {
                                updatePosition(.left)
                            }
                            
                            PositionPreviewCard(position: .right, isSelected: settings.panelPosition == .right) {
                                updatePosition(.right)
                            }
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // TIMER SETTINGS
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Timer Defaults")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Break Duration")
                                .foregroundColor(.primary)
                            Spacer()
                            
                            Menu {
                                Button("5 min") { settings.breakDuration = 300.0 }
                                Button("10 min") { settings.breakDuration = 600.0 }
                                Button("15 min") { settings.breakDuration = 900.0 }
                                Button("30 min") { settings.breakDuration = 1800.0 }
                                Button("45 min") { settings.breakDuration = 2700.0 }
                                Button("1 hour") { settings.breakDuration = 3600.0 }
                            } label: {
                                HStack {
                                    Text(formatDuration(settings.breakDuration))
                                        .foregroundColor(.white)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(width: 120) // Fixed width for consistent look
                                .background(GlassyBackground())
                            }
                            .menuStyle(.borderlessButton)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // TASK ALERTS
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("Task Alerts")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Toggle("", isOn: $settings.isTaskAlertEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .white.opacity(0.8)))
                                .labelsHidden()
                        }
                        
                        if settings.isTaskAlertEnabled {
                            VStack(alignment: .leading, spacing: 16) {
                                // Interval Selector
                                HStack {
                                    Text("Interval")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    
                                    Menu {
                                        Button("5 min") { settings.taskAlertInterval = 300.0 }
                                        Button("10 min") { settings.taskAlertInterval = 600.0 }
                                        Button("15 min") { settings.taskAlertInterval = 900.0 }
                                        Button("30 min") { settings.taskAlertInterval = 1800.0 }
                                        Button("1 hour") { settings.taskAlertInterval = 3600.0 }
                                    } label: {
                                        HStack {
                                            Text(formatDuration(settings.taskAlertInterval))
                                                .foregroundColor(.white)
                                                .fontWeight(.medium)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .frame(width: 120)
                                        .background(GlassyBackground())
                                    }
                                    .menuStyle(.borderlessButton)
                                }
                                
                                // Sound Info
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Sound")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(spacing: 12) {
                                        // Sound Picker
                                        Menu {
                                            ForEach(sounds, id: \.self) { sound in
                                                Button(action: { settings.taskAlertSound = sound }) {
                                                    HStack {
                                                        if settings.taskAlertSound == sound {
                                                            Image(systemName: "checkmark")
                                                        }
                                                        Text(sound)
                                                    }
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(settings.taskAlertSound)
                                                    .foregroundColor(.white)
                                                    .fontWeight(.medium)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .frame(width: 140)
                                            .background(GlassyBackground())
                                        }
                                        .menuStyle(.borderlessButton)
                                        
                                        Spacer()
                                        
                                        // Play Button
                                        Button(action: {
                                            playSound(named: settings.taskAlertSound, volume: settings.taskAlertVolume)
                                        }) {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white)
                                                .frame(width: 32, height: 32)
                                                .background(GlassyBackground())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                // Volume Slider
                                HStack(spacing: 12) {
                                    Image(systemName: "speaker.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Slider(value: $settings.taskAlertVolume, in: 0...1)
                                        .accentColor(.white)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.1))
                                                .frame(height: 4)
                                        )
                                    
                                    Image(systemName: "speaker.wave.3.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.leading, 4)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // ALERT SETTINGS
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("Alerts")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Toggle("", isOn: $settings.isAlertEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .white.opacity(0.8)))
                                .labelsHidden()
                        }
                        
                        if settings.isAlertEnabled {
                            VStack(alignment: .leading, spacing: 16) {
                                // Sound Info
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Sound")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(spacing: 12) {
                                        // Sound Picker
                                        Menu {
                                            ForEach(sounds, id: \.self) { sound in
                                                Button(action: { settings.alertSound = sound }) {
                                                    HStack {
                                                        if settings.alertSound == sound {
                                                            Image(systemName: "checkmark")
                                                        }
                                                        Text(sound)
                                                    }
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(settings.alertSound)
                                                    .foregroundColor(.white)
                                                    .fontWeight(.medium)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .frame(width: 140) // Fixed width for consistency
                                            .background(GlassyBackground())
                                        }
                                        .menuStyle(.borderlessButton)
                                        
                                        Spacer()
                                        
                                        // Play Button
                                        Button(action: {
                                            playSound(named: settings.alertSound, volume: settings.alertVolume)
                                        }) {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white)
                                                .frame(width: 32, height: 32)
                                                .background(GlassyBackground())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                // Volume Slider
                                HStack(spacing: 12) {
                                    Image(systemName: "speaker.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Slider(value: $settings.alertVolume, in: 0...1)
                                        .accentColor(.white)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.1))
                                                .frame(height: 4)
                                        )
                                    
                                    Image(systemName: "speaker.wave.3.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.leading, 4)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(24)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    func updatePosition(_ pos: PanelPosition) {
        settings.panelPosition = pos
        NotificationCenter.default.post(name: NSNotification.Name("UpdatePanelPosition"), object: nil)
    }
    
    func formatDuration(_ seconds: Double) -> String {
        let min = Int(seconds) / 60
        return "\(min) min"
    }
    
    func playSound(named name: String, volume: Double) {
        if let sound = NSSound(named: name) {
            sound.volume = Float(volume)
            sound.play()
        }
    }
}

// MARK: - Subviews & Styles

struct PositionPreviewCard: View {
    let position: PanelPosition
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Desktop Visual
                ZStack {
                    // Wallpaper / Screen
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    // The App Panel
                    HStack {
                        if position == .right { Spacer() }
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isSelected ? Color.white : Color.primary.opacity(0.5))
                            .frame(width: 16, height: 48)
                            .padding(position == .left ? .leading : .trailing, 6)
                            .shadow(radius: 2)
                        if position == .left { Spacer() }
                    }
                }
                
                // Label
                Text(position == .left ? "Screen Left" : "Screen Right")
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

struct GlassyBackground: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.4))
            
            RoundedRectangle(cornerRadius: 8)
                .fill(.thinMaterial)
                .opacity(0.5)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}
