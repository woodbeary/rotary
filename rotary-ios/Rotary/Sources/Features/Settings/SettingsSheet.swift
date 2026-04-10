import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var appearanceMode: RotaryAppearanceMode
    @Bindable var appModel: AppModel
    let bootstrap: MobileBootstrapReadyState
    @Bindable var voiceCoordinator: VoiceCoordinator
    @Bindable var mutationDispatcher: RotaryMutationDispatcher
    @Bindable var inferenceModeStore: InferenceModeStore

    @State private var screeningEnabled = false
    @State private var screeningLineNumber: String?
    @State private var isUpdatingScreening = false
    @State private var screeningError: String?
    @State private var isSendingTraceSnapshot = false
    @State private var traceStatusMessage: String?
    @State private var traceStore = RotaryTraceStore.shared
    @State private var localModelManager = LocalModelManager.shared
    @State private var failedMutationRecords: [OfflineMutationRecord] = []

    private var diagnosticsPayload: String {
        let lineSummary = bootstrap.lines
            .map { "\($0.phoneNumber) [\($0.status)] owner=\($0.ownerType ?? $0.role) incoming=\($0.mobileIncomingReady)" }
            .joined(separator: "\n")

        return """
        Rotary Diagnostics
        app_bundle=\(Bundle.main.bundleIdentifier ?? "unknown")
        api_base=\(AppConfig.shared.apiBaseURL.absoluteString)
        clerk_frontend=\(AppConfig.shared.clerkFrontendAPI)
        workspace=\(bootstrap.workspace?.name ?? bootstrap.org?.name ?? "Rotary")
        workspace_id=\(bootstrap.workspace?.id ?? "unknown")
        owner_main=\(bootstrap.ownerLine?.phoneNumber ?? "none")
        calls=\(bootstrap.callPreview.count)
        threads=\(bootstrap.threadPreview.count)
        agents=\(bootstrap.agents.count)
        folders=\(bootstrap.folders?.count ?? 0)
        voice_enabled=\(voiceCoordinator.tokenState?.enabled == true)
        incoming_ready=\(voiceCoordinator.tokenState?.incomingEnabled == true)
        voice_reason=\(voiceCoordinator.tokenState?.reason ?? "none")
        incoming_reason=\(voiceCoordinator.tokenState?.incomingReason ?? "none")
        screening_enabled=\(screeningEnabled)
        lines:
        \(lineSummary)
        recent_traces:
        \(traceStore.exportText(limit: 40))
        """
    }

    private var workspaceName: String {
        bootstrap.workspace?.name ?? bootstrap.org?.name ?? "Rotary"
    }

    private var mainLineNumber: String? {
        bootstrap.ownerLine?.phoneNumber
    }

    private var callingStatusTitle: String {
        let outgoingReady = voiceCoordinator.tokenState?.enabled == true
        let incomingReady = voiceCoordinator.tokenState?.incomingEnabled == true

        if outgoingReady && incomingReady {
            return "Ready for calls"
        }
        if outgoingReady {
            return "Ready to place calls"
        }
        return "Needs attention"
    }

    private var callingStatusDetail: String? {
        let outgoingReady = voiceCoordinator.tokenState?.enabled == true
        let incomingReady = voiceCoordinator.tokenState?.incomingEnabled == true

        if outgoingReady && incomingReady {
            return "This iPhone is ready to place and receive Rotary calls."
        }

        if let incomingReason = voiceCoordinator.tokenState?.incomingReason,
           !incomingReason.isEmpty,
           incomingReason != voiceCoordinator.tokenState?.reason {
            return incomingReason
        }

        if let voiceReason = voiceCoordinator.tokenState?.reason, !voiceReason.isEmpty {
            return voiceReason
        }

        if !incomingReady {
            return "Incoming calls are still being prepared on this iPhone."
        }

        return nil
    }

    private var screeningBinding: Binding<Bool> {
        Binding(
            get: { screeningEnabled },
            set: { newValue in
                updateScreeningToggle(newValue)
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                SettingsWorkspaceSection(
                    workspaceName: workspaceName,
                    mainLineNumber: mainLineNumber
                )

                SettingsAppearanceSection(appearanceMode: $appearanceMode)

                SettingsCallsSection(
                    screeningEnabled: screeningBinding,
                    screeningLineNumber: screeningLineNumber ?? mainLineNumber ?? "Main line",
                    isUpdatingScreening: isUpdatingScreening,
                    callingStatusTitle: callingStatusTitle,
                    callingStatusDetail: callingStatusDetail,
                    lastRegistrationAt: voiceCoordinator.lastRegistrationAt,
                    screeningError: screeningError
                )

                SettingsOfflineSection(
                    mode: Binding(
                        get: { inferenceModeStore.mode },
                        set: { inferenceModeStore.mode = $0 }
                    ),
                    localStatusTitle: localModelManager.statusTitle,
                    localStatus: localModelManager.status,
                    localStorageFootprint: localModelManager.storageFootprint,
                    isOnline: appModel.connectivityMonitor.isOnline,
                    pendingCount: mutationDispatcher.pendingCount,
                    failedCount: mutationDispatcher.failedCount,
                    isSyncing: mutationDispatcher.isSyncing,
                    lastSuccessfulSyncAt: mutationDispatcher.lastSuccessfulSyncAt,
                    latestFailureReason: mutationDispatcher.latestFailureReason,
                    failedMutationRecords: failedMutationRecords,
                    prepareLocalAssistant: {
                        await localModelManager.warmup()
                        if localModelManager.isReadyForExecution {
                            inferenceModeStore.mode = .local
                        } else {
                            inferenceModeStore.mode = .cloud
                        }
                    },
                    disableLocalAssistant: {
                        inferenceModeStore.mode = .cloud
                        localModelManager.unload()
                    },
                    retryNow: {
                        await mutationDispatcher.retryFailedMutations()
                        await refreshOfflineFailures()
                    }
                )

                SettingsSupportSection(
                    diagnosticsPayload: { diagnosticsPayload },
                    traceStore: traceStore,
                    isSendingTraceSnapshot: isSendingTraceSnapshot,
                    traceStatusMessage: traceStatusMessage,
                    sendTraceSnapshot: sendTraceSnapshot
                )

                SettingsDangerSection(signOut: signOut)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(RotaryBackdrop())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(appearanceMode.preferredColorScheme)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task(id: bootstrap.ownerLine?.id ?? bootstrap.session.orgId) {
            await loadScreening()
        }
        .task(id: "\(mutationDispatcher.pendingCount)|\(mutationDispatcher.failedCount)") {
            await refreshOfflineFailures()
        }
        .task(id: inferenceModeStore.mode.rawValue) {
            await localModelManager.refreshAvailability()
            if inferenceModeStore.mode == .local, !localModelManager.isReadyForExecution {
                inferenceModeStore.mode = .cloud
            }
        }
    }

    private func loadScreening() async {
        screeningEnabled = bootstrap.ownerLine?.screenUnknownCallers ?? false
        screeningLineNumber = bootstrap.ownerLine?.phoneNumber

        do {
            let payload = try await appModel.callScreeningSettings()
            screeningEnabled = payload.enabled
            screeningLineNumber = payload.phoneNumber
            screeningError = nil
        } catch {
            screeningError = error.localizedDescription
        }
    }

    private func updateScreeningToggle(_ newValue: Bool) {
        guard screeningEnabled != newValue else { return }
        screeningEnabled = newValue

        Task {
            await updateScreening(enabled: newValue)
        }
    }

    private func updateScreening(enabled: Bool) async {
        isUpdatingScreening = true
        defer { isUpdatingScreening = false }

        do {
            let payload = try await appModel.updateCallScreening(enabled: enabled)
            screeningEnabled = payload.enabled
            screeningLineNumber = payload.phoneNumber
            screeningError = nil
            RotaryHaptics.selection()
        } catch {
            screeningEnabled.toggle()
            screeningError = error.localizedDescription
            RotaryHaptics.error()
        }
    }

    private func signOut() {
        Task {
            await appModel.signOut()
            dismiss()
        }
    }

    private func sendTraceSnapshot() async {
        isSendingTraceSnapshot = true
        defer { isSendingTraceSnapshot = false }

        do {
            try await appModel.sendTraceSnapshot()
            traceStatusMessage = "Support snapshot sent to Rotary."
            RotaryHaptics.success()
        } catch {
            traceStatusMessage = "Support snapshot failed: \(error.localizedDescription)"
            RotaryHaptics.error()
        }
    }

    private func refreshOfflineFailures() async {
        failedMutationRecords = await mutationDispatcher.failedRecords()
    }
}

private struct SettingsWorkspaceSection: View {
    let workspaceName: String
    let mainLineNumber: String?

    var body: some View {
        Section("Your Rotary") {
            SettingsValueRow(title: "Account", value: workspaceName)
            if let mainLineNumber {
                SettingsValueRow(title: "Phone number", value: mainLineNumber)
            }
        }
    }
}

private struct SettingsAppearanceSection: View {
    @Binding var appearanceMode: RotaryAppearanceMode

    var body: some View {
        Section("Appearance") {
            Picker("Appearance", selection: $appearanceMode) {
                ForEach(RotaryAppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            SettingsDetailText("System follows your iPhone's Light and Dark Mode setting.")
        }
    }
}

private struct SettingsCallsSection: View {
    @Binding var screeningEnabled: Bool
    let screeningLineNumber: String
    let isUpdatingScreening: Bool
    let callingStatusTitle: String
    let callingStatusDetail: String?
    let lastRegistrationAt: Date?
    let screeningError: String?

    var body: some View {
        Section("Calls") {
            Toggle(isOn: $screeningEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Filter Unknown Callers")
                        .font(.body.weight(.semibold))
                    Text("Use \(screeningLineNumber) to screen numbers you do not know.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(isUpdatingScreening)

            SettingsValueRow(title: "Calling on this iPhone", value: callingStatusTitle)

            if let lastRegistrationAt {
                SettingsValueRow(
                    title: "Last checked",
                    value: lastRegistrationAt.formatted(.dateTime.month().day().hour().minute())
                )
            }

            if let callingStatusDetail, !callingStatusDetail.isEmpty {
                SettingsDetailText(callingStatusDetail)
            }
            if let screeningError, !screeningError.isEmpty {
                SettingsDetailText(screeningError, color: .red)
            }
        }
    }
}

private struct SettingsOfflineSection: View {
    @Binding var mode: InferenceMode
    let localStatusTitle: String
    let localStatus: LocalInferenceStatus
    let localStorageFootprint: String
    let isOnline: Bool
    let pendingCount: Int
    let failedCount: Int
    let isSyncing: Bool
    let lastSuccessfulSyncAt: Date?
    let latestFailureReason: String?
    let failedMutationRecords: [OfflineMutationRecord]
    let prepareLocalAssistant: () async -> Void
    let disableLocalAssistant: () -> Void
    let retryNow: () async -> Void

    private var isLocalReady: Bool {
        if case .ready = localStatus {
            return true
        }
        return false
    }

    private var shouldShowPrepareButton: Bool {
        switch localStatus {
        case .idle, .failed:
            return true
        case .loading, .ready, .unavailable:
            return false
        }
    }

    private var prepareButtonTitle: String {
        switch localStatus {
        case .failed:
            return "Retry Offline Assistant"
        default:
            return "Prepare Offline Assistant"
        }
    }

    var body: some View {
        Section("Offline & Local AI") {
            SettingsValueRow(title: "Offline assistant", value: localStatusTitle)
            SettingsValueRow(title: "Local storage", value: localStorageFootprint)

            if case .loading = localStatus {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.85)
                    Text("Preparing the on-device assistant")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isLocalReady {
                Toggle(
                    isOn: Binding(
                        get: { mode == .local },
                        set: { mode = $0 ? .local : .cloud }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Use Offline Assistant")
                            .font(.body.weight(.semibold))
                        Text("Replies run on this iPhone when Apple’s on-device model is ready.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if shouldShowPrepareButton {
                Button {
                    Task { await prepareLocalAssistant() }
                } label: {
                    Label(prepareButtonTitle, systemImage: "arrow.down.circle")
                }
            }

            if mode == .local && isLocalReady {
                Button("Use Cloud Instead") {
                    disableLocalAssistant()
                }
            }

            SettingsValueRow(
                title: "Connection",
                value: isOnline ? "Online" : "Offline"
            )
            SettingsValueRow(title: "Queued changes", value: "\(pendingCount)")
            SettingsValueRow(title: "Failed sync items", value: "\(failedCount)")

            if let lastSuccessfulSyncAt {
                SettingsValueRow(
                    title: "Last sync",
                    value: lastSuccessfulSyncAt.formatted(.dateTime.month().day().hour().minute())
                )
            }

            if let latestFailureReason, !latestFailureReason.isEmpty {
                SettingsDetailText(latestFailureReason, color: .red)
            }

            if failedCount > 0 {
                Button {
                    Task { await retryNow() }
                } label: {
                    Label(isSyncing ? "Syncing…" : "Retry Sync", systemImage: "arrow.clockwise")
                }
                .disabled(isSyncing)
            }

            if !failedMutationRecords.isEmpty {
                ForEach(failedMutationRecords.prefix(3), id: \.id) { record in
                    SettingsDetailText(
                        "\(record.payload.debugLabel): \(record.failureReason ?? "Unknown sync failure")",
                        color: .secondary
                    )
                }
            }

            SettingsDetailText(localStatus.detailText)
            SettingsDetailText(
                mode == .local
                    ? "Local mode is active for supported devices. Rotary automatically falls back to cloud if the on-device runtime is unavailable."
                    : "Cloud mode is the default and stays active on unsupported devices, including older iPhone SE-class hardware."
            )
        }
    }
}

private struct SettingsSupportSection: View {
    let diagnosticsPayload: () -> String
    let traceStore: RotaryTraceStore
    let isSendingTraceSnapshot: Bool
    let traceStatusMessage: String?
    let sendTraceSnapshot: () async -> Void

    var body: some View {
        Section("Help & Support") {
            ShareLink(item: diagnosticsPayload()) {
                Label("Share Support Report", systemImage: "square.and.arrow.up")
            }

            NavigationLink {
                RotarySupportToolsScreen(
                    traceStore: traceStore,
                    isSendingTraceSnapshot: isSendingTraceSnapshot,
                    traceStatusMessage: traceStatusMessage,
                    sendTraceSnapshot: sendTraceSnapshot
                )
            } label: {
                Label("Advanced Support Tools", systemImage: "wrench.and.screwdriver")
            }

            SettingsDetailText("The main settings stay simple. Support tools still live here when you need them.")
        }
    }
}

private struct SettingsTracingSection: View {
    @Bindable var traceStore: RotaryTraceStore
    let isSendingTraceSnapshot: Bool
    let traceStatusMessage: String?
    let sendTraceSnapshot: () async -> Void

    var body: some View {
        Section("Support Tools") {
            SettingsValueRow(
                title: "Runtime traces",
                value: traceStore.events.isEmpty ? "Idle" : "Active"
            )
            SettingsValueRow(title: "Remote diagnostics", value: "Ready")
            SettingsValueRow(
                title: "Sentry",
                value: AppConfig.shared.sentryDSN?.isEmpty == false ? "Configured" : "Not configured"
            )

            if AppConfig.shared.sentryDSN?.isEmpty != false {
                SettingsDetailText("This build records local traces and can send manual snapshots, but Sentry upload is off until ROTARY_SENTRY_DSN is set.")
            }

            NavigationLink {
                RotaryTraceLogScreen(traceStore: traceStore)
            } label: {
                Label("View Recent Traces", systemImage: "waveform.path.ecg")
            }

            Button {
                Task { await sendTraceSnapshot() }
            } label: {
                Label(
                    isSendingTraceSnapshot ? "Sending Support Snapshot" : "Send Support Snapshot",
                    systemImage: "paperplane"
                )
            }
            .disabled(isSendingTraceSnapshot)

            ShareLink(item: traceStore.exportText(limit: 160)) {
                Label("Share Trace Export", systemImage: "waveform.badge.plus")
            }

            if let traceStatusMessage, !traceStatusMessage.isEmpty {
                SettingsDetailText(
                    traceStatusMessage,
                    color: traceStatusMessage.contains("failed") ? .red : .secondary
                )
            }
        }
    }
}

private struct SettingsDangerSection: View {
    let signOut: () -> Void

    var body: some View {
        Section {
            Button("Sign Out", role: .destructive, action: signOut)
        }
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title, value: value)
            .font(.body)
    }
}

private struct SettingsDetailText: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = .secondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RotarySupportToolsScreen: View {
    @Bindable var traceStore: RotaryTraceStore
    let isSendingTraceSnapshot: Bool
    let traceStatusMessage: String?
    let sendTraceSnapshot: () async -> Void

    var body: some View {
        List {
            SettingsTracingSection(
                traceStore: traceStore,
                isSendingTraceSnapshot: isSendingTraceSnapshot,
                traceStatusMessage: traceStatusMessage,
                sendTraceSnapshot: sendTraceSnapshot
            )
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(RotaryBackdrop())
        .navigationTitle("Support Tools")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RotaryTraceLogScreen: View {
    let traceStore: RotaryTraceStore

    var body: some View {
        List {
            if traceStore.events.isEmpty {
                Text("No traces yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(traceStore.events) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.category.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(RotaryTheme.accent)
                            Spacer()
                            Text(event.timestamp.formatted(.dateTime.hour().minute().second()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(event.message)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Recent Traces")
        .navigationBarTitleDisplayMode(.inline)
    }
}
