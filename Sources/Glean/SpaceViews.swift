import AppKit
import SwiftUI

struct SpacePicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            ForEach(model.spaces.spaces) { space in
                Button {
                    model.selectSpace(space.id)
                } label: {
                    if space.id == model.spaces.selected?.id {
                        Label(space.name, systemImage: "checkmark")
                    } else {
                        Text(space.name)
                    }
                }
            }
            Divider()
            Button("New Space…") { model.sheet = .new }
                .disabled(!model.spaces.state.canCreate)
            Button("Edit Space…") {
                if let space = model.spaces.selected { model.sheet = .edit(space) }
            }
            .disabled(model.workspace == nil)
        } label: {
            Label(model.spaces.selected?.name ?? "No space", systemImage: "globe")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
    }
}

struct DataStateView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 48)).foregroundStyle(Brand.accent)
            Text(title).font(.title2.weight(.semibold))
            if let message = model.spaces.state.message {
                Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 480)
            } else {
                Text("A space holds the cards for one language you study, with your own language for translations.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 480)
            }
            HStack {
                Button("New Space…") { model.sheet = .new }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.spaces.state.canCreate)
                if model.spaces.state.message != nil {
                    Button("Reload") { model.reload() }
                    Button("Open Folder") { NSWorkspace.shared.open(model.spaces.root) }
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Glean")
    }

    private var icon: String {
        model.spaces.state.message == nil ? "globe" : "exclamationmark.triangle"
    }

    private var title: String {
        switch model.spaces.state {
        case .migrationNeeded: "Your cards need to be moved into a space"
        case .spacesUnreadable: "Couldn't read your spaces"
        case .orphanedSpaces: "Space folders found without spaces.json"
        default: "Create your first space"
        }
    }
}

struct SpaceSheet: View {
    @StateObject private var ui: SpaceSheetState
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    init(target: SpaceSheetTarget, existing: [Space]) {
        _ui = StateObject(wrappedValue: SpaceSheetState(target: target, existing: existing))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Name", text: $ui.name)
                Picker("I'm learning", selection: $ui.target) {
                    ForEach(Language.all) { Text($0.name).tag($0.id) }
                }
                Picker("My language", selection: $ui.native) {
                    ForEach(Language.all) { Text($0.name).tag($0.id) }
                }
                Picker("Level", selection: $ui.level) {
                    ForEach(Level.allCases) { Text($0.label).tag($0) }
                }
                Picker("Review direction", selection: $ui.direction) {
                    ForEach(ReviewDirection.allCases) { Text($0.label).tag($0) }
                }
                Text(ui.direction.detail).font(.caption).foregroundStyle(.secondary)
                Stepper("Daily goal: \(ui.dailyGoal) cards", value: $ui.dailyGoal, in: 1...200, step: 5)
                if let problem = ui.problem { Text(problem).foregroundStyle(.red).font(.callout) }
                if let message = ui.failure { Text(message).foregroundStyle(.red).font(.callout) }
            }
            .formStyle(.grouped)
            HStack {
                if ui.editing != nil {
                    Button("Delete Space…", role: .destructive) { ui.confirmingDelete = true }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(ui.editing == nil ? "Create" : "Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!ui.canSave)
            }
            .padding(16)
        }
        .frame(width: 460)
        .onChange(of: ui.target) { old, new in ui.targetChanged(from: old, to: new) }
        .confirmationDialog("Delete this space?", isPresented: $ui.confirmingDelete) {
            Button("Move to Trash Folder", role: .destructive) {
                if let space = ui.editing { model.deleteSpace(space.id) }
                dismiss()
            }
        } message: {
            Text("Its cards and history move to the Trash folder inside your Glean folder. Nothing is erased.")
        }
    }

    private func save() {
        do {
            if var space = ui.editing {
                space.name = ui.name
                space.target = ui.target
                space.native = ui.native
                space.level = ui.level
                space.dailyGoal = ui.dailyGoal
                space.direction = ui.direction
                try model.updateSpace(space)
            } else {
                try model.createSpace(name: ui.name, target: ui.target, native: ui.native, level: ui.level, dailyGoal: ui.dailyGoal, direction: ui.direction)
            }
            dismiss()
        } catch {
            ui.failure = error.localizedDescription
        }
    }
}

@MainActor
final class SpaceSheetState: ObservableObject {
    let editing: Space?
    @Published var name: String
    @Published var target: String
    @Published var native: String
    @Published var level: Level
    @Published var dailyGoal: Int
    @Published var direction: ReviewDirection
    @Published var failure: String?
    @Published var confirmingDelete = false

    init(target: SpaceSheetTarget, existing: [Space]) {
        switch target {
        case .edit(let space):
            editing = space
            name = space.name
            self.target = space.target
            native = space.native
            level = space.level
            dailyGoal = space.dailyGoal
            direction = space.direction
        case .new:
            editing = nil
            let nativeID = existing.first?.native ?? "pt-BR"
            let first = Language.all.first { language in
                !Language.sameBase(language.id, nativeID) && !existing.contains { Language.sameBase($0.target, language.id) }
            }
            native = nativeID
            self.target = first?.id ?? "es-ES"
            name = first?.languageName ?? ""
            level = .beginner
            dailyGoal = 20
            direction = .mixed
        }
    }

    var problem: String? {
        Language.sameBase(target, native) ? SpaceError.sameLanguage.localizedDescription : nil
    }

    var canSave: Bool {
        problem == nil && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func targetChanged(from old: String, to new: String) {
        guard editing == nil, name.isEmpty || name == Language.named(old).languageName else { return }
        name = Language.named(new).languageName
    }
}
