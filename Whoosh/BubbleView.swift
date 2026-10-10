import SwiftUI
import WhooshCore

struct BubbleContent: Equatable {
    enum Style {
        case question
        case comment
        /// Whoosh explaining why it can't do something the user asked.
        case notice
    }

    var style: Style
    var message: String
    var gesture: BubbleGesture
    /// Debug-build detail, such as capture size; never message content.
    var footnote: String?
}

/// One short bubble (§3.3). The predefined gestures are parameters of this
/// single view (amplitude and timing), not separately drawn variants.
struct BubbleView: View {
    let content: BubbleContent
    let onHover: (Bool) -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(accent))
                .rotationEffect(.degrees(appeared ? 0 : motion.iconTilt))

            VStack(alignment: .leading, spacing: 4) {
                Text(content.message)
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
                if let footnote = content.footnote {
                    Text(footnote)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 240, alignment: .leading)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(nsColor: .separatorColor)))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .scaleEffect(appeared ? 1 : motion.startScale, anchor: .bottomTrailing)
        .offset(y: appeared ? 0 : motion.startOffset)
        .opacity(appeared ? 1 : 0)
        // Room for the shadow; this margin is transparent, so clicks pass through it.
        .padding(14)
        .onHover(perform: onHover)
        .onAppear {
            withAnimation(motion.animation) { appeared = true }
        }
    }

    private var symbol: String {
        switch content.style {
        case .question: "questionmark"
        case .comment: "wind"
        case .notice: "info"
        }
    }

    private var accent: Color {
        switch content.style {
        case .question: .orange
        case .comment: .teal
        case .notice: .gray
        }
    }

    private struct Motion {
        var startScale: CGFloat = 1
        var startOffset: CGFloat = 0
        var iconTilt: Double = 0
        var animation: Animation = .easeOut(duration: 0.15)
    }

    /// The system's reduced-motion setting always wins, whatever style is chosen (§3.3).
    private var motion: Motion {
        if reduceMotion { return Motion(animation: .easeOut(duration: 0.2)) }
        switch content.gesture {
        case .questionArrival:
            return Motion(startScale: 0.85, iconTilt: -14, animation: .spring(response: 0.42, dampingFraction: 0.6))
        case .observationArrival:
            return Motion(startOffset: 14, animation: .easeOut(duration: 0.35))
        case .acknowledgement:
            return Motion(startScale: 0.92, animation: .spring(response: 0.3, dampingFraction: 0.7))
        case .staticFallback:
            return Motion()
        }
    }
}
