import SwiftUI

@main
struct GleanApp: App {
    private let model = AppModel(spaces: SpaceStore(root: SpaceStore.productionRoot, defaults: .standard), settings: AppSettings())

    var body: some Scene {
        Window("Glean", id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 860, minHeight: 600)
                .tint(Brand.accent)
        }
        .defaultSize(width: 1040, height: 720)

        MenuBarExtra {
            MenuBarView().environment(model)
        } label: {
            Image(nsImage: Brand.menuBarImage)
            if model.dueCount > 0 {
                Text("\(model.dueCount)")
            }
        }

        Settings {
            SettingsView()
                .environment(model)
                .tint(Brand.accent)
        }
    }
}

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(model.dueCount == 0 ? "Nothing to review right now" : "\(model.dueCount) cards to review")
        ForEach(model.spaceDue) { item in
            Button("\(item.space.name): \(item.due) due") {
                model.selectSpace(item.space.id)
                open(.review)
            }
        }
        Divider()
        Button("Review Now") { open(.review) }
            .keyboardShortcut("r")
        Button("Add Cards with AI…") { open(.add) }
        Button("Open Glean") { open(model.section) }
            .keyboardShortcut("o")
        Divider()
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
        Button("Quit Glean") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func open(_ section: AppSection) {
        model.section = section
        openWindow(id: "main")
        NSApp.activate()
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(AppSection.allCases, selection: $model.section) { section in
                Label(section.title, systemImage: section.symbol)
                    .badge(section == .review ? model.currentDue : 0)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
            .safeAreaInset(edge: .top) { SpacePicker().padding(.horizontal, 12).padding(.top, 4) }
        } detail: {
            if let workspace = model.workspace {
                switch model.section {
                case .review: ReviewView(workspace: workspace).id(workspace.space.id)
                case .cards: CardsView(workspace: workspace)
                case .add: AddChatView(workspace: workspace, ui: model.addChat(for: workspace.space))
                case .coach: CoachView(workspace: workspace)
                }
            } else {
                DataStateView()
            }
        }
        .sheet(item: $model.sheet) { target in
            SpaceSheet(target: target, existing: model.spaces.spaces).environment(model)
        }
        .alert("Glean", isPresented: Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.spaceError = nil } })) {
            Button("Reload") { model.reload() }
            Button("Open Folder") { NSWorkspace.shared.open(model.alertFolder) }
            if model.spaceError != nil { Button("OK", role: .cancel) { model.spaceError = nil } }
        } message: {
            Text(model.alertMessage ?? "")
        }
    }
}
