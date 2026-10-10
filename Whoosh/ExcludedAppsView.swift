import AppKit
import SwiftUI
import WhooshCore

/// The app exclusion list (§5.1): apps Whoosh never captures.
struct ExcludedAppsView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            List {
                HStack(spacing: 8) {
                    AppIcon(bundleIdentifier: Bundle.main.bundleIdentifier)
                    Text("Whoosh")
                    Spacer()
                    Text("Always excluded").foregroundStyle(.secondary)
                }
                ForEach(model.settings.exclusions.apps) { app in
                    HStack(spacing: 8) {
                        AppIcon(bundleIdentifier: app.bundleIdentifier)
                        Text(app.name)
                        Spacer()
                        Button {
                            model.removeExclusion(app.bundleIdentifier)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Stop excluding \(app.name)")
                    }
                }
            }
            .frame(minHeight: 200)

            HStack {
                Menu("Add Running App") {
                    ForEach(addableApps, id: \.bundleIdentifier) { app in
                        Button(app.name) { model.addExclusion(app) }
                    }
                }
                .fixedSize()
                .disabled(addableApps.isEmpty)
                Spacer()
                Button("Restore Defaults") { model.restoreDefaultExclusions() }
            }
        }
    }

    /// Regular apps that are running now and not excluded yet.
    private var addableApps: [ExcludedApp] {
        let own = Bundle.main.bundleIdentifier
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> ExcludedApp? in
            guard app.activationPolicy == .regular,
                  let id = app.bundleIdentifier, id != own,
                  !model.settings.exclusions.contains(id)
            else { return nil }
            return ExcludedApp(bundleIdentifier: id, name: app.localizedName ?? id)
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private struct AppIcon: View {
    let bundleIdentifier: String?

    var body: some View {
        if let bundleIdentifier, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "app.dashed")
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
        }
    }
}
