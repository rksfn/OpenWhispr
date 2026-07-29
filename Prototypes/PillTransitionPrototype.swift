// PROTOTYPE — throwaway UI study for the floating pill transition.
// Question: can one persistent capsule resize cleanly through every pill state?
// Variants: Calm, Direct, and Spring. Run with `make pill-prototype`.

import SwiftUI

@main
struct PillTransitionPrototypeApp: App {
    var body: some Scene {
        WindowGroup("Pill Transition Prototype") {
            PillTransitionPrototypeView()
        }
        .windowResizability(.contentSize)
    }
}

private enum PrototypeState: String, CaseIterable, Identifiable {
    case idle = "Idle"
    case recording = "Recording"
    case transcribing = "Transcribing"
    case formatting = "Formatting"

    var id: Self { self }

    var size: CGSize {
        switch self {
        case .idle: CGSize(width: 32, height: 8)
        case .recording: CGSize(width: 200, height: 40)
        case .transcribing: CGSize(width: 160, height: 32)
        case .formatting: CGSize(width: 140, height: 32)
        }
    }
}

private enum MotionProfile: String, CaseIterable, Identifiable {
    case calm = "Calm"
    case direct = "Direct"
    case spring = "Spring"

    var id: Self { self }

    var animation: Animation {
        switch self {
        case .calm: .easeInOut(duration: 0.32)
        case .direct: .easeOut(duration: 0.24)
        case .spring: .spring(response: 0.34, dampingFraction: 0.88)
        }
    }

    var contentRevealDelay: TimeInterval {
        switch self {
        case .calm: 0.24
        case .direct: 0.17
        case .spring: 0.20
        }
    }
}

private struct PillTransitionPrototypeView: View {
    @State private var state: PrototypeState = .idle
    @State private var profile: MotionProfile = .calm
    @State private var isLooping = false
    @State private var contentIsVisible = true
    @State private var contentRevealID = UUID()

    var body: some View {
        VStack(spacing: 28) {
            Text("Persistent pill study")
                .font(.title2.weight(.semibold))

            Text("Only the capsule resizes. No stacked pills, clipping, or window resizing.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ZStack {
                PrototypePill(state: state, contentIsVisible: contentIsVisible)
                    .animation(profile.animation, value: state)
            }
            .frame(width: 400, height: 100)
            .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))

            Picker("Motion", selection: $profile) {
                ForEach(MotionProfile.allCases) { profile in
                    Text(profile.rawValue).tag(profile)
                }
            }
            .pickerStyle(.segmented)

            Picker("State", selection: Binding(get: { state }, set: setState)) {
                ForEach(PrototypeState.allCases) { state in
                    Text(state.rawValue).tag(state)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button(isLooping ? "Stop loop" : "Loop sequence") {
                    isLooping.toggle()
                    if isLooping { playLoop() }
                }
                .keyboardShortcut(.space, modifiers: [])

                Text("State: \(state.rawValue) · \(Int(state.size.width)) × \(Int(state.size.height))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(width: 520)
    }

    private func playLoop() {
        let sequence: [PrototypeState] = [.idle, .recording, .transcribing, .formatting, .idle]
        for (index, nextState) in sequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.9) {
                guard isLooping else { return }
                setState(nextState)
                if index == sequence.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        guard isLooping else { return }
                        playLoop()
                    }
                }
            }
        }
    }

    private func setState(_ nextState: PrototypeState) {
        guard nextState != state else { return }

        let isGrowing = nextState.size.width > state.size.width || nextState.size.height > state.size.height
        contentRevealID = UUID()
        let revealID = contentRevealID

        if isGrowing {
            contentIsVisible = false
        }

        withAnimation(profile.animation) {
            state = nextState
        }

        guard isGrowing, nextState != .idle else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + profile.contentRevealDelay) {
            guard contentRevealID == revealID, state == nextState else { return }
            withAnimation(.easeOut(duration: 0.08)) {
                contentIsVisible = true
            }
        }
    }
}

private struct PrototypePill: View {
    let state: PrototypeState
    let contentIsVisible: Bool

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.145, green: 0.145, blue: 0.133))
                .overlay {
                    Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: .black.opacity(state == .idle ? 0 : 0.18), radius: 8, y: 3)

            content
                .opacity(contentIsVisible ? 1 : 0)
        }
        .frame(width: state.size.width, height: state.size.height)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            EmptyView()
        case .recording:
            HStack(spacing: 3) {
                Circle().fill(.red).frame(width: 6, height: 6).padding(.trailing, 4)
                ForEach(0..<24, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.white.opacity(0.8))
                        .frame(width: 3, height: CGFloat(5 + (index % 7) * 2))
                }
            }
        case .transcribing:
            Text("Transcribing…")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        case .formatting:
            Text("Formatting…")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
