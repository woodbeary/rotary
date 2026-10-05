import Observation
import SwiftUI

private enum FirstRunOnboardingStep: Int, CaseIterable {
    case intro
    case permissions
    case contacts
    case done

    var title: String {
        switch self {
        case .intro:
            return "Welcome to Rotary"
        case .permissions:
            return "Quick Permissions"
        case .contacts:
            return "Optional Contacts"
        case .done:
            return "You’re Ready"
        }
    }

    var subtitle: String {
        switch self {
        case .intro:
            return "Fast setup, no clutter."
        case .permissions:
            return "Enable what Rotary needs to work instantly."
        case .contacts:
            return "Import contacts now or skip and do it later."
        case .done:
            return "Calls, messages, and agents are ready."
        }
    }
}

struct FirstRunOnboardingFlow: View {
    @Bindable var appModel: AppModel

    @State private var step: FirstRunOnboardingStep = .intro
    @State private var permissionStatus = PermissionGateStatus(
        notifications: .notDetermined,
        microphone: .notDetermined,
        contacts: .notDetermined
    )
    @State private var availableContacts: [DeviceContactImportCandidate] = []
    @State private var importResult: DeviceContactsImportResult?
    @State private var importProgress = 0
    @State private var importTotal = 0
    @State private var isWorking = false
    @State private var errorMessage: String?

    @Environment(\.scenePhase) private var scenePhase

    private let permissionCenter = RotaryPermissionCenter.shared

    var body: some View {
        RotaryCenteredShell {
            RotaryGlassCard {
                header

                switch step {
                case .intro:
                    introStep
                case .permissions:
                    permissionsStep
                case .contacts:
                    contactsStep
                case .done:
                    doneStep
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .interactiveDismissDisabled(true)
        .task {
            await refreshPermissions()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task { await refreshPermissions() }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(RotaryTheme.accent)
                .frame(width: 64, height: 64)
                .background(RotaryTheme.softSurface, in: Circle())

            HStack(spacing: 6) {
                ForEach(0 ..< FirstRunOnboardingStep.allCases.count, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(index == step.rawValue ? RotaryTheme.accent : RotaryTheme.accent.opacity(0.20))
                        .frame(width: index == step.rawValue ? 18 : 8, height: 8)
                }
            }

            Text("STEP \(step.rawValue + 1) OF \(FirstRunOnboardingStep.allCases.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(step.title)
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)

            Text(step.subtitle)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var introStep: some View {
        VStack(spacing: 14) {
            Text("One tap to grant essentials, one optional contacts step, then you’re in.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Continue") {
                RotaryHaptics.selection()
                step = .permissions
            }
            .buttonStyle(RotaryPrimaryButtonStyle())
        }
    }

    private var permissionsStep: some View {
        VStack(spacing: 12) {
            permissionRow(for: .notifications)
            permissionRow(for: .microphone)
            permissionRow(for: .contacts)

            HStack(spacing: 10) {
                Button("Enable Required") {
                    Task { await requestRequiredPermissions() }
                }
                .buttonStyle(RotaryPrimaryButtonStyle())
                .disabled(isWorking)

                if !permissionStatus.canProceed {
                    Button("Settings") {
                        permissionCenter.openSettings()
                    }
                    .buttonStyle(RotarySecondaryButtonStyle())
                }
            }

            Button("Continue") {
                RotaryHaptics.selection()
                step = .contacts
            }
            .buttonStyle(RotaryPrimaryButtonStyle())
            .disabled(!permissionStatus.canProceed || isWorking)
        }
    }

    private var contactsStep: some View {
        VStack(spacing: 12) {
            Text("Contacts import is optional. Rotary works without it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if importTotal > 0 {
                ProgressView(value: Double(importProgress), total: Double(importTotal))
                    .tint(RotaryTheme.accent)
                Text("\(importProgress) of \(importTotal) imported")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let importResult {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Created: \(importResult.created)")
                    Text("Queued: \(importResult.queued)")
                    Text("Failed: \(importResult.failed)")
                }
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RotaryTheme.softSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(spacing: 10) {
                Button("Import Contacts") {
                    Task { await importContacts() }
                }
                .buttonStyle(RotaryPrimaryButtonStyle())
                .disabled(isWorking)

                Button("Skip") {
                    RotaryHaptics.selection()
                    step = .done
                }
                .buttonStyle(RotarySecondaryButtonStyle())
                .disabled(isWorking)
            }

            if importResult != nil {
                Button("Continue") {
                    RotaryHaptics.selection()
                    step = .done
                }
                .buttonStyle(RotaryPrimaryButtonStyle())
                .disabled(isWorking)
            }
        }
    }

    private var doneStep: some View {
        VStack(spacing: 14) {
            Text("Rotary is configured for speed. You can change permissions anytime in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Enter Rotary") {
                appModel.markFirstRunOnboardingCompleted()
                RotaryHaptics.success()
            }
            .buttonStyle(RotaryPrimaryButtonStyle())
        }
    }

    private func permissionRow(for step: PermissionGateStep) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))
                    if step.isRequired {
                        Text("Required")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RotaryTheme.softSurface, in: Capsule())
                    }
                }

                Text(permissionLabel(permissionStatus.status(for: step)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(buttonTitle(permissionStatus.status(for: step))) {
                Task { await requestPermission(for: step) }
            }
            .buttonStyle(RotarySecondaryButtonStyle())
            .disabled(isWorking)
        }
        .padding(12)
        .background(RotaryTheme.incomingBubble, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
        )
    }

    private func refreshPermissions() async {
        permissionStatus = await permissionCenter.currentStatus()
    }

    private func requestPermission(for step: PermissionGateStep) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        _ = await permissionCenter.requestPermission(for: step)
        await refreshPermissions()
        RotaryHaptics.selection()
    }

    private func requestRequiredPermissions() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        permissionStatus = await permissionCenter.requestRequiredPermissions()
        if permissionStatus.canProceed {
            RotaryHaptics.success()
        } else {
            RotaryHaptics.warning()
        }
    }

    private func importContacts() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        if permissionStatus.contacts != .authorized {
            _ = await permissionCenter.requestContactsPermission()
            await refreshPermissions()
        }

        guard permissionStatus.contacts == .authorized else {
            errorMessage = "Contacts access is off. Enable it in Settings or skip this step."
            return
        }

        if availableContacts.isEmpty {
            availableContacts = await appModel.loadDeviceContactsForImport(limit: 300)
        }

        guard !availableContacts.isEmpty else {
            importResult = DeviceContactsImportResult(skipped: 1)
            return
        }

        importProgress = 0
        importTotal = availableContacts.count
        importResult = await appModel.importDeviceContacts(availableContacts) { completed, total in
            importProgress = completed
            importTotal = total
        }
        RotaryHaptics.success()
    }

    private func buttonTitle(_ status: PermissionAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "Enabled"
        case .notDetermined:
            return "Enable"
        case .denied, .restricted:
            return "Fix"
        }
    }

    private func permissionLabel(_ status: PermissionAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "Enabled"
        case .notDetermined:
            return "Not enabled yet"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        }
    }
}
