import AppKit
import SwiftUI
import WhooshCore

/// The last image that would have gone to the provider. Only test builds keep
/// one (`AppModel.lastCapture`), in memory, for the §11.1 boundary tests.
struct DebugCapture {
    let target: CaptureTarget
    let image: CapturedImage
    let capturedAt: Date

    var scopeDescription: String {
        switch target {
        case .window: "This window"
        case .display(let display): display.focusWindow == nil ? "Whole screen, desktop in front" : "Whole screen"
        }
    }
}

/// Shows the last capture so the boundary tests can be checked by eye. Test builds only.
struct CaptureViewerView: View {
    let model: AppModel
    @State private var outlinesWindowInUse = false

    var body: some View {
        Group {
            if let capture = model.lastCapture, let image = NSImage(data: capture.image.data) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(capture.scopeDescription) · \(capture.image.pixelWidth)×\(capture.image.pixelHeight) px · \(capture.capturedAt.formatted(date: .omitted, time: .standard))")
                        .font(.callout)
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .overlay { if outlinesWindowInUse { focusOutline(capture.image) } }
                        .border(Color(nsColor: .separatorColor))
                    if capture.image.focusRegion != nil {
                        Toggle("Outline the window in use (drawn by this viewer, not part of the picture)", isOn: $outlinesWindowInUse)
                            .font(.caption)
                    }
                    Text("Test builds only. This picture is held in memory, never saved, and cleared when you pause.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            } else {
                ContentUnavailableView(
                    "No capture yet",
                    systemImage: "photo",
                    description: Text("Press \(Shortcut.lookNow.displayText), then look here.")
                )
            }
        }
        .frame(minWidth: 640, minHeight: 440)
    }

    private func focusOutline(_ image: CapturedImage) -> some View {
        GeometryReader { geometry in
            if let region = image.focusRegion, image.pixelWidth > 0 {
                let scale = geometry.size.width / CGFloat(image.pixelWidth)
                Rectangle()
                    .stroke(.yellow, lineWidth: 2)
                    .frame(width: region.width * scale, height: region.height * scale)
                    .position(x: region.midX * scale, y: region.midY * scale)
            }
        }
    }
}
