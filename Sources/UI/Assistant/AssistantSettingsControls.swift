import SwiftUI

struct AssistantSettingsControls: View {
    @ObservedObject var settings: SettingsStore
    @StateObject private var ollamaModels = LocalOllamaModelStore()
    @State private var assistantStatusMessage: String?
    @State private var showAdvanced = false

    let theme: AppTheme?

    private var isEmbedded: Bool { theme != nil }
    private var currentTheme: AppTheme { theme ?? .glass }
    private var isWhiteTheme: Bool { currentTheme == .white }
    private var menuTextColor: Color { isWhiteTheme ? Color.primary : Color.white }
    private var availableModels: [String] {
        let detected = ollamaModels.models.map(\.name)
        let current = settings.assistantOllamaModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = current.isEmpty ? detected : detected + [current]
        return Array(Set(combined)).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Toggle("Enable Assistant", isOn: $settings.assistantEnabled)
                Spacer()
                Button(showAdvanced ? "Hide advanced" : "Advanced") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAdvanced.toggle()
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Assistant model")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        Task {
                            await refreshDetectedModels()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh detected Ollama models")
                }

                if availableModels.isEmpty {
                    assistantTextFieldControl("Ollama Model", text: $settings.assistantOllamaModel)
                } else {
                    Picker("Assistant model", selection: $settings.assistantOllamaModel) {
                        ForEach(availableModels, id: \.self) { modelName in
                            Text(modelName).tag(modelName)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .modifier(AssistantFieldChrome(theme: currentTheme, enabled: isEmbedded))
                }

                if !ollamaModels.models.isEmpty {
                    Text("Detected \(ollamaModels.models.count) local model\(ollamaModels.models.count == 1 ? "" : "s").")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let lastError = ollamaModels.lastError {
                    Text(lastError)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("Use Handy for dictation if you want voice, then paste the transcript here.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if showAdvanced {
                advancedFields
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let assistantStatusMessage {
                Text(assistantStatusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .task(id: settings.assistantOllamaBaseURL) {
            await refreshDetectedModels()
        }
    }

    @ViewBuilder
    private var advancedFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            assistantField(title: "Ollama Base URL", text: $settings.assistantOllamaBaseURL)
            Text("Advanced settings only affect the local Ollama connection. Helpy's assistant is text-only for now.")
                .font(.caption)
                .foregroundColor(.secondary)

            assistantActionButton("Test Ollama") {
                Task {
                    let coordinator = AssistantCoordinator()
                    assistantStatusMessage = await coordinator.testOllamaConnection()
                    await refreshDetectedModels()
                }
            }
        }
    }

    @ViewBuilder
    private func assistantField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            assistantTextFieldControl(title, text: text)
        }
    }

    private func refreshDetectedModels() async {
        await ollamaModels.load(from: settings.assistantOllamaBaseURL)
    }

    @ViewBuilder
    private func assistantTextFieldControl(_ title: String, text: Binding<String>) -> some View {
        if isEmbedded {
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .modifier(AssistantFieldChrome(theme: currentTheme, enabled: true))
        } else {
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private func assistantActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        if isEmbedded {
            Button(title, action: action)
                .buttonStyle(.plain)
                .modifier(AssistantButtonChrome(theme: currentTheme, enabled: true))
        } else {
            Button(title, action: action)
                .buttonStyle(.bordered)
        }
    }
}

private struct AssistantFieldChrome: ViewModifier {
    let theme: AppTheme
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(GlassyBackground(theme: theme))
                .foregroundColor(theme == .white ? .primary : .white)
        } else {
            content
        }
    }
}

private struct AssistantButtonChrome: ViewModifier {
    let theme: AppTheme
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(theme == .white ? .primary : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(GlassyBackground(theme: theme))
        } else {
            content
        }
    }
}
