import SwiftUI
import MnemoOrchestrator

enum StarterProfileScreenState: Equatable {
    case hidden
    case consent
    case building(StarterProfileProgress)
    case review(StarterProfileBuildResult)
    case failed(String)

    var isAvailable: Bool {
        if case .hidden = self { return false }
        return true
    }
}

struct StarterProfileView: View {
    @ObservedObject var vm: NotchViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch vm.starterProfileState {
            case .hidden:
                EmptyView()
            case .consent:
                consent
            case .building(let progress):
                building(progress)
            case .review(let result):
                review(result)
            case .failed(let message):
                failure(message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .transition(Motion.blurMorph(reduceMotion: reduceMotion))
        .animation(Motion.adaptive(Motion.grow, reduceMotion: reduceMotion),
                   value: vm.starterProfileState)
        .overlay(alignment: .bottom) {
            HomeIndicator().frame(height: Surface.trayHandle)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Starter profile")
    }

    private var consent: some View {
        VStack(alignment: .leading, spacing: 15) {
            header("Make Mnemo yours", symbol: "person.crop.circle.badge.sparkles")
            Text("Choose the local folders Mnemo may sample to build a starter profile.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 4) {
                ForEach(StarterProfileSource.allCases, id: \.self) { source in
                    Toggle(isOn: binding(for: source)) {
                        Label(source.title, systemImage: sourceSymbol(source))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .toggleStyle(.checkbox)
                    .frame(height: 29)
                }
            }

            Label("Up to 8 recent supported files · 4 MB total · processed on-device",
                  systemImage: "lock.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(2)

            Spacer(minLength: 0)
            HStack {
                Button("Skip") { vm.skipStarterProfile() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.62))
                Spacer()
                Button {
                    vm.startStarterProfile()
                } label: {
                    Label("Build profile", systemImage: "sparkles")
                }
                .buttonStyle(.glassProminent)
                .disabled(vm.selectedStarterProfileSources.isEmpty)
            }
        }
    }

    private func building(_ progress: StarterProfileProgress) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            header("Building your profile", symbol: "person.text.rectangle")
            Spacer(minLength: 18)
            HStack(spacing: 14) {
                ProgressView().controlSize(.small).tint(.white)
                Text(StarterProfilePresentation.status(for: progress))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(2)
            }
            Spacer()
            Label("Local model · local memory", systemImage: "lock.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.56))
        }
    }

    private func review(_ result: StarterProfileBuildResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header("Your starter profile", symbol: "checkmark.seal.fill")
            ScrollView(.vertical, showsIndicators: false) {
                Text(result.profile)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(.white.opacity(0.9))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 185)
            if !result.sampledFiles.isEmpty {
                Text("From \(result.sampledFiles.prefix(3).joined(separator: " · "))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
            }
            HStack {
                Label("Saved to Mnemo", systemImage: "internaldrive.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                Spacer()
                Button("Done") { vm.finishStarterProfileReview() }
                    .buttonStyle(.glassProminent)
            }
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            header("Profile not created", symbol: "exclamationmark.triangle.fill")
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            HStack {
                Button("Skip") { vm.skipStarterProfile() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.62))
                Spacer()
                Button("Try again") { vm.retryStarterProfile() }
                    .buttonStyle(.glassProminent)
            }
        }
    }

    private func header(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
    }

    private func binding(for source: StarterProfileSource) -> Binding<Bool> {
        Binding(
            get: { vm.selectedStarterProfileSources.contains(source) },
            set: { selected in vm.setStarterProfileSource(source, selected: selected) }
        )
    }

    private func sourceSymbol(_ source: StarterProfileSource) -> String {
        switch source {
        case .documents: return "doc.fill"
        case .desktop: return "menubar.dock.rectangle"
        case .downloads: return "arrow.down.circle.fill"
        }
    }
}
