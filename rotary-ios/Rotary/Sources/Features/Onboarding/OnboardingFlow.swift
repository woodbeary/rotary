import AVFoundation
import Observation
import SwiftUI

struct OnboardingFlow: View {
    @Bindable var appModel: AppModel
    let notice: MobileStatusNotice

    @State private var step: Int = 1
    @State private var workspaceName = "Rotary"
    @State private var areaCode = "951"
    @State private var containsDigits = ""
    @State private var searchResults: [MobileSearchNumber] = []
    @State private var selectedNumber: MobileSearchNumber?
    @State private var agentName = "Rotary"
    @State private var selectedVoice = "Rachel"
    @State private var selectedVoiceProfileId: String?
    @State private var voiceOptions: [MobileVoicePreset] = []
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var previewPlayer = OnboardingVoicePreviewPlayer()

    private var capabilities: MobileCapabilityFlags? {
        notice.capabilities
    }

    private var isNumberSearchEnabled: Bool {
        capabilities?.numberSearchEnabled ?? true
    }

    private var isLineProvisioningEnabled: Bool {
        capabilities?.lineProvisioningEnabled ?? true
    }

    private var curatedVoiceOptions: [MobileVoicePreset] {
        let sorted = voiceOptions.sorted { lhs, rhs in
            switch (lhs.previewUrl == nil, rhs.previewUrl == nil) {
            case (false, true): return true
            case (true, false): return false
            default: return lhs.name < rhs.name
            }
        }
        return Array(sorted.prefix(8))
    }

    private var voiceChoices: [MobileVoicePreset] {
        if curatedVoiceOptions.isEmpty {
            return [
                MobileVoicePreset(
                    id: "fallback-rachel",
                    name: "Rachel",
                    provider: "elevenlabs",
                    category: "fallback",
                    description: "Warm and clear.",
                    previewUrl: nil,
                    labels: ["accent": "american", "gender": "female"]
                )
            ]
        }
        return curatedVoiceOptions
    }

    var body: some View {
        RotaryCenteredShell {
            RotaryGlassCard {
                header

                Group {
                    switch step {
                    case 1:
                        workspaceStep
                    case 2:
                        searchStep
                    case 3:
                        chooseNumberStep
                    case 4:
                        agentStep
                    default:
                        voiceStep
                    }
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if isWorking {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .task(id: step) {
            if step == 5, voiceOptions.isEmpty {
                await loadVoicePresets()
            }
        }
        .onDisappear {
            previewPlayer.stop()
        }
    }

    private var header: some View {
        VStack(alignment: .center, spacing: 10) {
            Image(systemName: headerIcon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(RotaryTheme.accent)
                .frame(width: 66, height: 66)
                .background(RotaryTheme.softSurface, in: Circle())

            HStack(spacing: 6) {
                ForEach(1 ... 5, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(index == step ? RotaryTheme.accent : RotaryTheme.accent.opacity(0.18))
                        .frame(width: index == step ? 18 : 7, height: 7)
                }
            }

            Text("STEP \(step) OF 5")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(stepTitle)
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)
            Text(stepSubtitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var workspaceStep: some View {
        VStack(spacing: 14) {
            TextField("Workspace name", text: $workspaceName)
                .rotaryTextFieldStyle()

            Button("Create workspace") {
                Task { await createWorkspace() }
            }
            .buttonStyle(RotaryPrimaryButtonStyle())
        }
    }

    private var searchStep: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                TextField("951", text: $areaCode)
                    .keyboardType(.numberPad)
                    .rotaryTextFieldStyle()
                TextField("Digits", text: $containsDigits)
                    .keyboardType(.numberPad)
                    .rotaryTextFieldStyle()
            }

            Button("Search") {
                Task { await search() }
            }
            .buttonStyle(RotaryPrimaryButtonStyle())
            .disabled(!isNumberSearchEnabled)

            if !isNumberSearchEnabled {
                Text("Live number search is not enabled for this workspace yet. Rotary needs Twilio number provisioning turned on first.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var chooseNumberStep: some View {
        VStack(spacing: 12) {
            if searchResults.isEmpty {
                Text("Search first to pull live numbers from Twilio.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(searchResults) { result in
                    Button {
                        selectedNumber = result
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.phoneNumber)
                                    .font(.headline)
                                Text([result.locality, result.region].compactMap { $0 }.joined(separator: ", "))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: selectedNumber?.phoneNumber == result.phoneNumber ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedNumber?.phoneNumber == result.phoneNumber ? RotaryTheme.accent : .secondary)
                        }
                        .padding(16)
                        .background(RotaryTheme.softSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Use this number") {
                Task { await provisionNumber() }
            }
            .buttonStyle(RotaryPrimaryButtonStyle())
            .disabled(selectedNumber == nil || !isLineProvisioningEnabled)

            if !isLineProvisioningEnabled {
                Text("Line provisioning is blocked right now. Turn on Twilio number purchasing before this account can claim a number.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var agentStep: some View {
        VStack(spacing: 14) {
            TextField("Agent name", text: $agentName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .rotaryTextFieldStyle()

            Button("Continue") {
                step = 5
            }
            .buttonStyle(RotaryPrimaryButtonStyle())
            .disabled(agentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var voiceStep: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(voiceChoices, id: \.id) { voice in
                    OnboardingVoiceOptionRow(
                        voice: voice,
                        isSelected: selectedVoiceProfileId == voice.id,
                        isPlaying: previewPlayer.isPlaying(voice.id),
                        onPreviewToggle: { previewPlayer.toggle(for: voice) },
                        onSelect: {
                            selectedVoice = voice.name
                            selectedVoiceProfileId = voice.id
                        }
                    )
                }
            }

            Button("Create first agent") {
                Task { await createAgent() }
            }
            .buttonStyle(RotaryPrimaryButtonStyle())
            .disabled(selectedVoiceProfileId == nil || agentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var headerIcon: String {
        switch step {
        case 1: return "building.2.crop.circle"
        case 2: return "magnifyingglass.circle"
        case 3: return "simcard.2"
        case 4: return "person.crop.circle.badge.plus"
        default: return "waveform"
        }
    }

    private var stepTitle: String {
        switch step {
        case 1: return "Name your space"
        case 2: return "Choose a number"
        case 3: return "Pick one"
        case 4: return "Name your agent"
        default: return "Pick a voice"
        }
    }

    private var stepSubtitle: String {
        switch step {
        case 1: return "One clean home."
        case 2: return "Area code first."
        case 3: return "Your main line."
        case 4: return "Keep it simple."
        default: return "You can teach it the rest in chat."
        }
    }

    private func createWorkspace() async {
        await runStep {
            try await appModel.createWorkspace(named: workspaceName.trimmingCharacters(in: .whitespacesAndNewlines))
            step = 2
        }
    }

    private func search() async {
        guard isNumberSearchEnabled else {
            errorMessage = "Live number search is not enabled for this workspace yet."
            return
        }
        await runStep {
            searchResults = try await appModel.searchNumbers(
                areaCode: areaCode.trimmingCharacters(in: .whitespacesAndNewlines),
                contains: containsDigits.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : containsDigits.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            selectedNumber = searchResults.first
            step = 3
        }
    }

    private func provisionNumber() async {
        guard isLineProvisioningEnabled else {
            errorMessage = "Twilio number provisioning is turned off for this workspace."
            return
        }
        guard let selectedNumber else { return }
        await runStep {
            try await appModel.provisionOwnerLine(phoneNumber: selectedNumber.phoneNumber)
            step = 4
        }
    }

    private func createAgent() async {
        await runStep {
            try await appModel.createFirstAgent(
                name: agentName.trimmingCharacters(in: .whitespacesAndNewlines),
                purpose: "Everyday",
                voiceName: selectedVoice,
                voiceProfileId: selectedVoiceProfileId,
                thinkingMode: "balanced",
                folderId: nil
            )
        }
    }

    private func loadVoicePresets() async {
        do {
            let presets = try await appModel.listVoicePresets()
            voiceOptions = presets
            if let first = voiceChoices.first, selectedVoiceProfileId == nil {
                selectedVoice = first.name
                selectedVoiceProfileId = first.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runStep(_ action: @escaping () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct OnboardingVoiceOptionRow: View {
    let voice: MobileVoicePreset
    let isSelected: Bool
    let isPlaying: Bool
    let onPreviewToggle: () -> Void
    let onSelect: () -> Void

    private var labelValues: [String] {
        let keys = ["accent", "gender", "age", "use_case"]
        return keys.compactMap { key in
            guard let value = voice.labels?[key], !value.isEmpty else { return nil }
            return value.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPreviewToggle) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RotaryTheme.accent)
                    .frame(width: 36, height: 36)
                    .background(RotaryTheme.elevatedSurface, in: Circle())
            }
            .buttonStyle(.plain)

            Button(action: onSelect) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(voice.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)

                        if let description = voice.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        if !labelValues.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(labelValues, id: \.self) { label in
                                        Text(label)
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(RotaryTheme.softSurface, in: Capsule())
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 12)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? RotaryTheme.accent : Color.secondary)
                }
                .padding(14)
                .background(RotaryTheme.softSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

@MainActor
@Observable
private final class OnboardingVoicePreviewPlayer {
    private var player: AVPlayer?
    private(set) var activeVoiceID: String?

    func isPlaying(_ voiceID: String) -> Bool {
        activeVoiceID == voiceID
    }

    func toggle(for voice: MobileVoicePreset) {
        guard let previewUrl = voice.previewUrl, let url = URL(string: previewUrl) else {
            return
        }

        if activeVoiceID == voice.id {
            stop()
            return
        }

        stop()
        let player = AVPlayer(url: url)
        self.player = player
        activeVoiceID = voice.id
        player.play()
    }

    func stop() {
        player?.pause()
        player = nil
        activeVoiceID = nil
    }
}
