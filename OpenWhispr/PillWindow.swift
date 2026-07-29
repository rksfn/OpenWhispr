import AppKit
import SwiftUI
import Combine

enum PillState: Hashable {
    case idle
    case downloading(progress: Double)
    case recording
    case recordingLocked
    case recordingSummarize
    case recordingLockedSummarize
    case recordingQuestion
    case processing
    case polishing
    case error(String)
    case learned(String)
    case answer(String)

    var size: NSSize {
        switch self {
        case .idle:
            NSSize(width: 32, height: 8)
        case .downloading:
            NSSize(width: 220, height: 32)
        case .recording, .recordingLocked, .recordingSummarize, .recordingLockedSummarize, .recordingQuestion:
            NSSize(width: 200, height: 40)
        case .processing:
            NSSize(width: 160, height: 32)
        case .polishing:
            NSSize(width: 140, height: 32)
        case .error:
            NSSize(width: 280, height: 32)
        case .learned:
            NSSize(width: 260, height: 32)
        case .answer:
            NSSize(width: 360, height: 72)
        }
    }
}

class PillWindow: NSPanel {
    private let pillState = PillStateModel()
    private var hostingView: NSHostingView<PillView>!
    var onRightClick: (() -> Void)?
    var onIdleClick: (() -> Void)?
    private var frameTransitionID = UUID()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 32, height: 8),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        // Allow right-click in idle, block other mouse events
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = false

        hostingView = NSHostingView(rootView: PillView(state: pillState))
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        contentView = hostingView

        // Enable mouse tracking for hover detection
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        hostingView.addTrackingArea(trackingArea)

        updateFrame()
    }

    override func mouseEntered(with event: NSEvent) {
        pillState.isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        pillState.isHovered = false
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }

    override func mouseDown(with event: NSEvent) {
        // Click on answer pill copies to clipboard
        if case .answer(let text) = pillState.state {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            setState(.learned("Copied to clipboard"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.setState(.idle)
            }
            return
        }
        // Click idle pill to start locked recording
        if case .idle = pillState.state {
            onIdleClick?()
            return
        }
        // Swallow — don't steal focus
    }

    func show() {
        orderFrontRegardless()
    }

    var currentState: PillState { pillState.state }
    var isHovered: Bool { pillState.isHovered }

    func setState(_ state: PillState) {
        DispatchQueue.main.async {
            let previousState = self.pillState.state
            self.pillState.transition(to: state)
            self.updateFrame(for: NSSize(
                width: max(previousState.size.width, state.size.width),
                height: max(previousState.size.height, state.size.height)
            ))

            let transitionID = UUID()
            self.frameTransitionID = transitionID
            DispatchQueue.main.asyncAfter(deadline: .now() + PillView.transitionDuration) { [weak self] in
                guard self?.frameTransitionID == transitionID else { return }
                self?.updateFrame()
            }
        }
    }

    func pushLevel(_ level: Float) {
        DispatchQueue.main.async {
            self.pillState.pushLevel(level)
        }
    }

    private func updateFrame(for requestedSize: NSSize? = nil) {
        guard let screen = NSScreen.main else { return }

        let visibleSize = requestedSize ?? pillState.state.size
        let size = canvasSize(for: visibleSize)
        // Shadows belong to the SwiftUI capsule itself. An NSPanel shadow is always
        // rectangular and would expose the transparent canvas during transitions.
        hasShadow = false

        let x = (screen.frame.width - size.width) / 2
        let y: CGFloat = 12 - PillView.shadowInsets.bottom

        // The panel is just a transparent canvas. It changes size outside the visible
        // animation so the one SwiftUI capsule never gets clipped by a rectangle.
        setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        hostingView.frame = NSRect(origin: .zero, size: size)
    }

    private func canvasSize(for visibleSize: NSSize) -> NSSize {
        NSSize(
            width: visibleSize.width + PillView.shadowInsets.leading + PillView.shadowInsets.trailing,
            height: visibleSize.height + PillView.shadowInsets.top + PillView.shadowInsets.bottom
        )
    }
}

class PillStateModel: ObservableObject {
    @Published var state: PillState = .idle
    @Published private(set) var contentIsVisible = true
    @Published var isHovered: Bool = false
    @Published var levels: [Float] = Array(repeating: 0, count: 24)

    private var contentRevealID = UUID()

    func transition(to newState: PillState) {
        let previousState = state
        let isGrowing = newState.size.width > previousState.size.width || newState.size.height > previousState.size.height
        let revealID = UUID()
        contentRevealID = revealID

        if isGrowing, newState != .idle {
            contentIsVisible = false
        } else {
            contentIsVisible = true
        }
        state = newState

        guard isGrowing, newState != .idle else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + PillView.contentRevealDelay) { [weak self] in
            guard self?.contentRevealID == revealID, self?.state == newState else { return }
            withAnimation(.easeOut(duration: 0.08)) {
                self?.contentIsVisible = true
            }
        }
    }

    func pushLevel(_ level: Float) {
        levels.append(level)
        if levels.count > 24 {
            levels.removeFirst()
        }
    }
}

// MARK: - Views

struct PillView: View {
    @ObservedObject var state: PillStateModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            pillShell
            switch state.state {
            case .idle:
                idlePill
            case .downloading(let progress):
                downloadingPill(progress: progress)
            case .recording:
                recordingPill
            case .recordingLocked:
                recordingLockedPill
            case .recordingSummarize:
                recordingSummarizePill
            case .recordingQuestion:
                recordingQuestionPill
            case .recordingLockedSummarize:
                recordingLockedSummarizePill
            case .processing:
                processingPill
            case .polishing:
                polishingPill
            case .error(let message):
                errorPill(message: message)
            case .learned(let message):
                learnedPill(message: message)
            case .answer(let message):
                answerPill(message: message)
            }
        }
        .frame(width: visibleSize.width, height: visibleSize.height)
        .animation(.easeOut(duration: Self.transitionDuration), value: state.state)
        .padding(Self.shadowInsets)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    static let transitionDuration = 0.24
    static let contentRevealDelay = 0.17
    static let shadowInsets = EdgeInsets(top: 8, leading: 12, bottom: 10, trailing: 12)

    private var visibleSize: NSSize {
        state.state == .idle ? NSSize(width: 32, height: 6) : state.state.size
    }

    private var pillShell: some View {
        Capsule()
            .fill(state.state == .idle
                ? PillTheme.idleSurface(for: colorScheme, isHovered: state.isHovered)
                : PillTheme.surface(for: colorScheme))
            .overlay(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(state.state == .idle ? 0 : 0.09), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(PillTheme.border(for: colorScheme), lineWidth: 1)
            )
            .shadow(color: .black.opacity(state.state == .idle ? 0 : 0.18), radius: 8, y: 3)
    }

    // A visible neutral handle at rest, independent of the desktop appearance.
    private var idlePill: some View {
        Color.clear
            .animation(.easeInOut(duration: 0.15), value: state.isHovered)
            .onHover { hovering in
                state.isHovered = hovering
            }
    }

    private func downloadingPill(progress: Double) -> some View {
        HStack(spacing: 8) {
            Text("Downloading model… \(Int(progress * 100))%")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .frame(width: 220, height: 32)
        .opacity(state.contentIsVisible ? 1 : 0)
    }

    private var recordingPill: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
                .padding(.trailing, 4)

            ForEach(0..<state.levels.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.white.opacity(0.8))
                    .frame(width: 3, height: barHeight(for: state.levels[i]))
            }
        }
        .padding(.horizontal, 14)
        .frame(width: 200, height: 40)
        .opacity(state.contentIsVisible ? 1 : 0)
    }

    private var recordingLockedPill: some View {
        HStack(spacing: 3) {
            Image(systemName: "lock.fill")
                .font(.system(size: 8))
                .foregroundColor(.orange)
                .padding(.trailing, 4)

            ForEach(0..<state.levels.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.white.opacity(0.8))
                    .frame(width: 3, height: barHeight(for: state.levels[i]))
            }
        }
        .padding(.horizontal, 14)
        .frame(width: 200, height: 40)
        .opacity(state.contentIsVisible ? 1 : 0)
    }

    private var recordingSummarizePill: some View {
        HStack(spacing: 3) {
            Image(systemName: "text.redaction")
                .font(.system(size: 8))
                .foregroundColor(.purple)
                .padding(.trailing, 4)

            ForEach(0..<state.levels.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.purple.opacity(0.6))
                    .frame(width: 3, height: barHeight(for: state.levels[i]))
            }
        }
        .padding(.horizontal, 14)
        .frame(width: 200, height: 40)
        .opacity(state.contentIsVisible ? 1 : 0)
    }

    private var recordingQuestionPill: some View {
        HStack(spacing: 3) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 8))
                .foregroundColor(.blue)
                .padding(.trailing, 4)

            ForEach(0..<state.levels.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.blue.opacity(0.6))
                    .frame(width: 3, height: barHeight(for: state.levels[i]))
            }
        }
        .padding(.horizontal, 14)
        .frame(width: 200, height: 40)
        .opacity(state.contentIsVisible ? 1 : 0)
    }

    private var recordingLockedSummarizePill: some View {
        HStack(spacing: 3) {
            Image(systemName: "lock.fill")
                .font(.system(size: 8))
                .foregroundColor(.purple)
                .padding(.trailing, 4)

            ForEach(0..<state.levels.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.purple.opacity(0.6))
                    .frame(width: 3, height: barHeight(for: state.levels[i]))
            }
        }
        .padding(.horizontal, 14)
        .frame(width: 200, height: 40)
        .opacity(state.contentIsVisible ? 1 : 0)
    }

    private var processingPill: some View {
        Text("Transcribing…")
            .font(.system(size: 11, weight: .medium))
        .foregroundColor(.white.opacity(0.7))
        .frame(width: 160, height: 32)
        .opacity(state.contentIsVisible ? 1 : 0)
    }

    private var polishingPill: some View {
        Text("Formatting…")
            .font(.system(size: 11, weight: .medium))
        .foregroundColor(.white.opacity(0.7))
        .frame(width: 140, height: 32)
        .opacity(state.contentIsVisible ? 1 : 0)
    }

    private func errorPill(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(.orange)
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(width: 280, height: 32)
        .opacity(state.contentIsVisible ? 1 : 0)
    }

    private func learnedPill(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 10))
                .foregroundColor(.green)
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(width: 260, height: 32)
        .opacity(state.contentIsVisible ? 1 : 0)
    }

    private func answerPill(message: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9))
                    .foregroundColor(.blue)
                Text("Answer")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("click to copy")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.3))
            }
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 360)
        .opacity(state.contentIsVisible ? 1 : 0)
    }

    private func barHeight(for level: Float) -> CGFloat {
        let min: CGFloat = 3
        let max: CGFloat = 22
        return min + CGFloat(level) * (max - min)
    }
}

private enum PillTheme {
    static func surface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.227, green: 0.224, blue: 0.212) // lifted charcoal on dark desktops
            : Color(red: 0.145, green: 0.145, blue: 0.133) // deep charcoal on light desktops
    }

    static func idleSurface(for colorScheme: ColorScheme, isHovered: Bool) -> Color {
        if colorScheme == .dark {
            return isHovered
                ? Color(red: 0.69, green: 0.68, blue: 0.64)
                : Color(red: 0.55, green: 0.54, blue: 0.51)
        }
        return isHovered
            ? Color(red: 0.43, green: 0.43, blue: 0.40)
            : Color(red: 0.34, green: 0.34, blue: 0.32)
    }

    static func border(for colorScheme: ColorScheme) -> Color {
        .white.opacity(colorScheme == .dark ? 0.22 : 0.14)
    }
}
