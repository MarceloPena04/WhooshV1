import AppKit
import Carbon.HIToolbox
import OSLog

/// Global shortcuts (§4.4). Every default uses Control-Option-Command, so no
/// bare key, and no key the user's apps commonly need, is ever taken.
enum Shortcut: UInt32, CaseIterable {
    case lookNow = 1
    case togglePause
    case toggleHush
    case dismissBubble

    var key: String {
        switch self {
        case .lookNow: "l"
        case .togglePause: "p"
        case .toggleHush: "h"
        case .dismissBubble: "d"
        }
    }

    fileprivate var keyCode: Int {
        switch self {
        case .lookNow: kVK_ANSI_L
        case .togglePause: kVK_ANSI_P
        case .toggleHush: kVK_ANSI_H
        case .dismissBubble: kVK_ANSI_D
        }
    }

    static let modifierFlags: NSEvent.ModifierFlags = [.control, .option, .command]
    fileprivate static let carbonModifiers = UInt32(controlKey | optionKey | cmdKey)

    var displayText: String { "⌃⌥⌘" + key.uppercased() }
}

/// Registers the shortcuts with `RegisterEventHotKey`, which needs neither the
/// Accessibility nor the Input Monitoring permission and sees only these exact
/// combinations, never other keystrokes (§2.2, §4.4).
@MainActor
final class HotKeyCenter {
    private static let signature: OSType = 0x5748_5348 // "WHSH"

    private let handler: (Shortcut) -> Void
    private var eventHandler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef] = []
    /// Shortcuts another app had already taken.
    private(set) var unavailable: [Shortcut] = []

    init(handler: @escaping (Shortcut) -> Void) {
        self.handler = handler
    }

    func registerAll() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                let id = hotKeyID.id
                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { center.handle(id) }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard status == noErr else {
            Log.lifecycle.error("Shortcut handler not installed: \(status, privacy: .public)")
            unavailable = Shortcut.allCases
            return
        }

        for shortcut in Shortcut.allCases {
            var hotKey: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: shortcut.rawValue)
            let status = RegisterEventHotKey(UInt32(shortcut.keyCode), Shortcut.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKey)
            if status == noErr, let hotKey {
                hotKeys.append(hotKey)
            } else {
                unavailable.append(shortcut)
                Log.lifecycle.error("Shortcut \(shortcut.rawValue, privacy: .public) unavailable: \(status, privacy: .public)")
            }
        }
        Log.lifecycle.info("Registered \(self.hotKeys.count, privacy: .public) of \(Shortcut.allCases.count, privacy: .public) shortcuts")
    }

    private func handle(_ id: UInt32) {
        guard let shortcut = Shortcut(rawValue: id) else { return }
        handler(shortcut)
    }
}
