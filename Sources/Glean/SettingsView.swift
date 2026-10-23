import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section("AI") {
                Picker("Connect to", selection: $settings.engine) {
                    ForEach(AIEngine.allCases) { Text($0.displayName).tag($0) }
                }
                EngineStatus(engine: settings.engine)
                if settings.engine == .claudeCode {
                    TextField("Model (optional)", text: $settings.claudeModel, prompt: Text("default, e.g. sonnet or opus"))
                }
                if settings.engine == .codex {
                    TextField("Model (optional)", text: $settings.codexModel, prompt: Text("default"))
                }
                Text("Glean runs the CLI you already use, with your own login. No API keys. With None, everything works except the AI buttons.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Reminders") {
                Toggle("Remind me to review", isOn: $settings.remindersOn)
                if settings.remindersOn {
                    HourPicker(hours: $settings.reminderHours)
                    Text("Glean only notifies you at these times when cards are due, and lists a few of them.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Data") {
                LabeledContent("Glean folder") {
                    Button(model.spaces.root.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")) {
                        NSWorkspace.shared.open(model.spaces.root)
                    }
                    .buttonStyle(.link)
                }
                Text("The language you study, your language, level and daily goal belong to each space. Change them with Edit Space… in the sidebar.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .onChange(of: settings.remindersOn) { model.refresh() }
        .onChange(of: settings.reminderHours) { model.refresh() }
    }
}

struct EngineStatus: View {
    let engine: AIEngine

    var body: some View {
        if engine != .none {
            if let path = AgentCLI.binary(for: engine)?.path {
                Label("Found at \(path)", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.callout)
            } else {
                Label("\(engine.displayName) not found. Install it and sign in, then reopen Settings.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange).font(.callout)
            }
        }
    }
}

struct HourPicker: View {
    @Binding var hours: [Int]
    private let options = Array(7...22)

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
            ForEach(options, id: \.self) { hour in
                Toggle("\(hour)h", isOn: Binding(
                    get: { hours.contains(hour) },
                    set: { on in hours = on ? (hours + [hour]).sorted() : hours.filter { $0 != hour } }
                ))
                .toggleStyle(.button)
            }
        }
    }
}
