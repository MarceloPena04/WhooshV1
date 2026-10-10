import SwiftUI
import WhooshCore

struct SettingsView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Look at").font(.headline)
                CaptureScopePicker(model: model)
                Toggle("Include the pointer", isOn: Binding(get: { model.settings.includesPointer }, set: { model.setIncludesPointer($0) }))
                Text("Shows the AI where you're pointing. The pointer can cover a few letters of small text.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Excluded apps").font(.headline)
                Text("Whoosh never captures these apps. In Whole Screen they're removed from the picture, and while one is in use Whoosh doesn't look at all. You can also exclude the app you're using from the menu-bar menu.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ExcludedAppsView(model: model)
            }
        }
        .padding(20)
        .frame(width: 460, height: 620)
    }
}

/// The capture scope choice (§5.1), explained where it is made.
struct CaptureScopePicker: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Look at", selection: Binding(get: { model.settings.captureScope }, set: { model.setCaptureScope($0) })) {
                Text("This window").tag(CaptureScope.window)
                Text("Whole screen").tag(CaptureScope.screen)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            Text(explanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var explanation: String {
        switch model.settings.captureScope {
        case .window:
            "Only the window you're working in. Other windows, the desktop, and Whoosh itself are never in the picture."
        case .screen:
            "Everything on the screen you're working on, including other windows, the desktop, and the menu bar. Once an AI model is connected, all of it goes to the provider, including any chats or emails left open. Excluded apps, notifications, and password prompts are removed from the picture. Consider excluding chat and mail apps."
        }
    }
}
