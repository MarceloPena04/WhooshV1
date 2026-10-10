import OSLog

/// Content-free diagnostics (§8.2): status, counts, timings, and reason codes.
/// Never log message text, model output, app or window names, bundle
/// identifiers, or image data. Interpolated strings are private by default;
/// mark only enum codes and numbers as public. Use `notice` rather than
/// `info`: macOS keeps notices on disk, so tests can be checked afterwards.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Whoosh"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let capture = Logger(subsystem: subsystem, category: "capture")
    static let overlay = Logger(subsystem: subsystem, category: "overlay")
}
