import SwiftUI

/// First-run explanation (§3.1): what Whoosh observes, where data goes, what
/// is saved, Pause versus Hush, the exclusion list, and the permission. The
/// first observation starts only when the user chooses Start.
struct OnboardingView: View {
    let model: AppModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Welcome to Whoosh")
                        .font(.largeTitle.bold())

                    VStack(alignment: .leading, spacing: 8) {
                        section("What Whoosh looks at", """
                            You choose: the window you're working in, or the whole screen you're working on. \
                            Either way, never your excluded apps or Whoosh itself, and nothing while paused \
                            or while a password field is active. You can change this later in Settings.
                            """)
                        CaptureScopePicker(model: model)
                    }

                    section("Where it goes", """
                        This early version sends nothing anywhere: its bubbles are built-in placeholders. \
                        Once an AI model is connected, the captured window will go to that provider using your own key, \
                        and the provider may keep it under its own policy. \
                        Whoosh doesn't save screenshots to its files, caches, or logs.
                        """)

                    section("What stays on this Mac", "Your settings, such as the excluded apps below.")

                    section("Pause and Hush", """
                        Pause stops Whoosh from looking; every launch starts paused. \
                        Hush keeps Whoosh quiet, with no bubbles. Hush is separate from macOS Focus.
                        """)

                    section("Shortcuts", """
                        \(Shortcut.lookNow.displayText) Look Now · \(Shortcut.togglePause.displayText) Pause or Resume · \
                        \(Shortcut.toggleHush.displayText) Hush · \(Shortcut.dismissBubble.displayText) Dismiss a bubble
                        """)

                    permission

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Excluded apps").font(.headline)
                        ExcludedAppsView(model: model)
                    }
                }
                .padding(24)
            }

            Divider()
            HStack {
                Spacer()
                Button("Not Now", action: onClose)
                Button("Start Whoosh") {
                    model.completeOnboarding()
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.hasPermission)
            }
            .padding(16)
        }
        .frame(width: 540, height: 680)
        // Pick up the permission as soon as it's granted in System Settings.
        .task {
            while !Task.isCancelled {
                model.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var permission: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Screen Recording permission").font(.headline)
            if model.hasPermission {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                HStack {
                    Label("Not allowed yet", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Allow Screen Recording…") { model.requestPermission() }
                }
            }
            Text("""
                macOS grants this permission for the whole screen; Whoosh's own rules narrow it to the window in use. \
                macOS may ask you to confirm it again from time to time. If you decline, Whoosh stops looking until you allow it again. \
                After you allow it, macOS may ask you to quit and reopen Whoosh.
                """)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
