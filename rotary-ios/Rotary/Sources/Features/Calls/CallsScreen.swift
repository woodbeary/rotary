import SwiftUI
import UIKit
import AudioToolbox

private let rotaryDebugOpenCallsKeypadNotification = Notification.Name("rotary.debug.openCallsKeypad")
private let rotaryDebugOpenCallsKeypadWithDigitsNotification = Notification.Name("rotary.debug.openCallsKeypadWithDigits")
private let rotaryDebugCallsKeypadDeleteHoldNotification = Notification.Name("rotary.debug.callsKeypadDeleteHold")
private let rotaryDebugCallsOpenDialResultsNotification = Notification.Name("rotary.debug.callsOpenDialResults")

private enum CallsSurface: String, CaseIterable, Identifiable {
    case recents = "Recents"
    case contacts = "Contacts"
    case voicemail = "Voicemail"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .recents:
            return "clock"
        case .contacts:
            return "person.2"
        case .voicemail:
            return "waveform"
        }
    }

    var navigationTitle: String {
        switch self {
        case .recents:
            return "Calls"
        case .contacts:
            return "Contacts"
        case .voicemail:
            return "Voicemail"
        }
    }
}

private enum CallsRecentsFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case missed = "Missed"

    var id: String { rawValue }
}

private struct CallsContactSection: Identifiable {
    let letter: String
    let contacts: [RotaryCallContact]

    var id: String { letter }
}

private enum CallsPhonePalette {
    static let chromeFill = RotaryTheme.secondarySurface
    static let chromeBorder = RotaryTheme.elevatedStroke
    static let keyFill = RotaryTheme.elevatedSurface
    static let contactAvatarFill = RotaryTheme.avatarTint
    static let chromeText = Color.primary
}

private typealias CallsContactRow = RotaryCallContact

private enum CallsSuggestionKind: String, Hashable {
    case contact
    case history
    case agent

    var sectionTitle: String {
        switch self {
        case .contact, .agent:
            return "Names"
        case .history:
            return "Numbers"
        }
    }
}

private struct CallsSuggestion: Identifiable, Hashable {
    let id: String
    let phoneNumber: String
    let title: String
    let subtitle: String
    let sourceLine: String?
    let systemImage: String
    let kind: CallsSuggestionKind
}

private struct KeypadDigit: Identifiable {
    let primary: String
    let secondary: String

    var id: String { primary }

    var displayPrimary: String {
        switch primary {
        case "*":
            return "∗"
        default:
            return primary
        }
    }

    var usesCompactPrimaryFont: Bool {
        primary == "*" || primary == "#"
    }
}

struct CallsScreen: View {
    let bootstrap: MobileBootstrapReadyState
    let store: CallsStore
    let messagesStore: MessagesStore
    let api: RotaryAPIClient
    let tokenProvider: RotaryTokenProvider
    let showSettings: () -> Void
    let startCall: (_ call: MobileCall) -> Void
    let startManualCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void
    let openLiveAssist: (_ call: MobileCall) -> Void
    let onMissedCallCountChange: ((Int) -> Void)?
    let onViewingMissedCallsChange: ((Bool) -> Void)?

    @State private var selectedSurface: CallsSurface = .recents
    @State private var selectedRecentsFilter: CallsRecentsFilter = .all
    @State private var dialNumber = ""
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @State private var isDialpadPresented = false
    @State private var showingDialSearchResults = false
    @State private var showingCreateContact = false
    @State private var showingUnifiedSearch = false
    @State private var acknowledgedMissedNotificationCount = 0
    @State private var recentsVisibleCount = 40
    @State private var voicemailVisibleCount = 40
    @State private var debugDeleteHoldTask: Task<Void, Never>?

    init(
        bootstrap: MobileBootstrapReadyState,
        store: CallsStore,
        messagesStore: MessagesStore,
        api: RotaryAPIClient,
        tokenProvider: @escaping RotaryTokenProvider,
        showSettings: @escaping () -> Void,
        startCall: @escaping (_ call: MobileCall) -> Void,
        startManualCall: @escaping (_ phoneNumber: String, _ fromNumber: String?) -> Void,
        openLiveAssist: @escaping (_ call: MobileCall) -> Void,
        onMissedCallCountChange: ((Int) -> Void)? = nil,
        onViewingMissedCallsChange: ((Bool) -> Void)? = nil
    ) {
        self.bootstrap = bootstrap
        self.store = store
        self.messagesStore = messagesStore
        self.api = api
        self.tokenProvider = tokenProvider
        self.showSettings = showSettings
        self.startCall = startCall
        self.startManualCall = startManualCall
        self.openLiveAssist = openLiveAssist
        self.onMissedCallCountChange = onMissedCallCountChange
        self.onViewingMissedCallsChange = onViewingMissedCallsChange
    }

    private let keypadDigits: [KeypadDigit] = [
        KeypadDigit(primary: "1", secondary: ""),
        KeypadDigit(primary: "2", secondary: "ABC"),
        KeypadDigit(primary: "3", secondary: "DEF"),
        KeypadDigit(primary: "4", secondary: "GHI"),
        KeypadDigit(primary: "5", secondary: "JKL"),
        KeypadDigit(primary: "6", secondary: "MNO"),
        KeypadDigit(primary: "7", secondary: "PQRS"),
        KeypadDigit(primary: "8", secondary: "TUV"),
        KeypadDigit(primary: "9", secondary: "WXYZ"),
        KeypadDigit(primary: "*", secondary: ""),
        KeypadDigit(primary: "0", secondary: "+"),
        KeypadDigit(primary: "#", secondary: ""),
    ]

    private var manualDialSourceLine: String? {
        bootstrap.ownerLine?.phoneNumber ?? bootstrap.capabilities.defaultMainLine
    }

    private var allCalls: [MobileCall] {
        store.allCalls
    }

    private var pendingMissedNotificationCount: Int {
        max(store.missedCallCount - acknowledgedMissedNotificationCount, 0)
    }

    private var filteredRecents: [MobileCall] {
        switch selectedRecentsFilter {
        case .all:
            return allCalls
        case .missed:
            return allCalls.filter { $0.status.lowercased().contains("missed") }
        }
    }

    private var pagedRecents: [MobileCall] {
        Array(filteredRecents.prefix(recentsVisibleCount))
    }

    private var voicemailSource: [MobileCall] {
        store.voicemails
    }

    private var hasVoicemailSurface: Bool {
        !voicemailSource.isEmpty
    }

    private var availableMenuSurfaces: [CallsSurface] {
        var surfaces: [CallsSurface] = [.recents, .contacts]
        if hasVoicemailSurface {
            surfaces.append(.voicemail)
        }
        return surfaces.filter { $0 != selectedSurface }
    }

    private var voicemailCalls: [MobileCall] {
        voicemailSource
    }

    private var pagedVoicemailCalls: [MobileCall] {
        Array(voicemailCalls.prefix(voicemailVisibleCount))
    }

    private var contacts: [CallsContactRow] {
        let rows = store.contacts
        guard !searchText.isEmpty else { return rows }
        let query = searchText.lowercased()
        return rows.filter {
            $0.name.lowercased().contains(query) || $0.phoneNumber.lowercased().contains(query)
        }
    }

    private var contactSections: [CallsContactSection] {
        let grouped = Dictionary(grouping: contacts) { contact in
            let trimmed = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let firstLetter = trimmed.first(where: \.isLetter) else { return "#" }
            return String(firstLetter).uppercased()
        }

        return grouped.keys.sorted().map { key in
            CallsContactSection(
                letter: key,
                contacts: grouped[key, default: []].sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            )
        }
    }

    private var ownerCardName: String {
        let label = bootstrap.transferDestinations
            .map(\.label)
            .first { $0.rangeOfCharacter(from: .letters) != nil }
        return label ?? bootstrap.org?.name ?? "My Card"
    }

    private var ownerCardNumber: String? {
        bootstrap.ownerCellNumber ?? bootstrap.ownerLine?.phoneNumber
    }

    private var keypadSuggestions: [CallsSuggestion] {
        let query = dialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        var seen = Set<String>()
        var results: [CallsSuggestion] = []

        for contact in contacts {
            guard matchesDialQuery(query, phoneNumber: contact.phoneNumber, name: contact.name),
                  seen.insert(contact.phoneNumber).inserted else {
                continue
            }

            results.append(
                CallsSuggestion(
                    id: "contact:\(contact.phoneNumber)",
                    phoneNumber: contact.phoneNumber,
                    title: contact.name,
                    subtitle: contact.latestPreview ?? contact.phoneNumber,
                    sourceLine: contact.sourceLine,
                    systemImage: "person.crop.circle.fill",
                    kind: .contact
                )
            )
        }

        for call in allCalls {
            guard let phoneNumber = normalizedPhone(call.contactPhone ?? call.toNumber ?? call.fromNumber),
                  matchesDialQuery(query, phoneNumber: phoneNumber, name: call.contactName),
                  seen.insert(phoneNumber).inserted else {
                continue
            }

            results.append(
                CallsSuggestion(
                    id: "call:\(phoneNumber)",
                    phoneNumber: phoneNumber,
                    title: call.contactName,
                    subtitle: call.summary ?? statusLabel(for: call),
                    sourceLine: manualDialSourceLine,
                    systemImage: "phone.fill",
                    kind: .history
                )
            )
        }

        for agent in bootstrap.agents {
            guard let phoneNumber = normalizedPhone(agent.assignedPhoneNumber),
                  matchesDialQuery(query, phoneNumber: phoneNumber, name: agent.name),
                  seen.insert(phoneNumber).inserted else {
                continue
            }

            results.append(
                CallsSuggestion(
                    id: "agent:\(agent.id)",
                    phoneNumber: phoneNumber,
                    title: agent.name,
                    subtitle: "Agent line",
                    sourceLine: manualDialSourceLine,
                    systemImage: "person.2.fill",
                    kind: .agent
                )
            )
        }

        return results
    }

    private var primaryKeypadSuggestion: CallsSuggestion? {
        keypadSuggestions.first
    }

    private var remainingKeypadSuggestionCount: Int {
        max(keypadSuggestions.count - 1, 0)
    }

    private var dialSearchNameSuggestions: [CallsSuggestion] {
        keypadSuggestions.filter { $0.kind.sectionTitle == "Names" }
    }

    private var dialSearchNumberSuggestions: [CallsSuggestion] {
        keypadSuggestions.filter { $0.kind.sectionTitle == "Numbers" }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() })
                surfaceContent
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack {
                    Spacer(minLength: 0)

                    RotaryFloatingActionButton(
                        systemName: "circle.grid.3x3.fill",
                        tint: RotaryTheme.callAccent,
                        glassTintOpacity: 0.72
                    ) {
                        RotaryHaptics.softTap()
                        isDialpadPresented = true
                    }
                    .accessibilityLabel("Keypad")
                    .accessibilityIdentifier("rotary.callsKeypadButton")
                    .padding(.trailing, 14)
                    .padding(.bottom, 2)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .tabBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                surfaceToolbar
            }
            .navigationDestination(isPresented: $showingUnifiedSearch) {
                CallsUnifiedSearchScreen(
                    api: api,
                    tokenProvider: tokenProvider,
                    messagesStore: messagesStore,
                    allCalls: allCalls,
                    voicemails: voicemailSource,
                    startManualCall: startManualCall,
                    seeAllResults: { target in
                        switch target {
                        case .calls:
                            selectedSurface = .recents
                            selectedRecentsFilter = .all
                        case .voicemail:
                            if hasVoicemailSurface {
                                selectedSurface = .voicemail
                            }
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingCreateContact) {
            CallsCreateContactSheet(
                initialName: nil,
                initialPhoneNumber: isDialpadPresented ? dialNumber.nonEmptyTrimmed : nil,
                api: api,
                tokenProvider: tokenProvider
            )
        }
        .fullScreenCover(isPresented: $isDialpadPresented) {
            NavigationStack {
                keypadDestination
            }
        }
        .task {
            onMissedCallCountChange?(store.missedCallCount)
            publishMissedViewState()
            await store.refreshCallSurfaces()
            synchronizeMissedNotificationAcknowledgement(with: store.missedCallCount)
        }
        .onChange(of: store.missedCallCount) { _, count in
            onMissedCallCountChange?(count)
            synchronizeMissedNotificationAcknowledgement(with: count)
        }
        .onChange(of: selectedRecentsFilter) { _, _ in
            recentsVisibleCount = 40
            publishMissedViewState()
        }
        .onChange(of: selectedSurface) { _, surface in
            if surface != .contacts {
                searchText = ""
                isSearchVisible = false
            }
            recentsVisibleCount = 40
            voicemailVisibleCount = 40
            publishMissedViewState()
            guard surface == .voicemail, !store.hasLoadedVoicemail else { return }
            Task { await store.loadVoicemails(forceRefresh: false) }
        }
        .onChange(of: store.voicemails.count) { _, count in
            guard count == 0, selectedSurface == .voicemail else { return }
            selectedSurface = .recents
        }
        .onReceive(NotificationCenter.default.publisher(for: rotaryDebugOpenCallsKeypadNotification)) { _ in
            selectedSurface = .recents
            isSearchVisible = false
            searchText = ""
            isDialpadPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: rotaryDebugOpenCallsKeypadWithDigitsNotification)) { notification in
            selectedSurface = .recents
            isSearchVisible = false
            searchText = ""
            if let digits = notification.userInfo?["digits"] as? String {
                dialNumber = digits
            }
            isDialpadPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: rotaryDebugCallsKeypadDeleteHoldNotification)) { notification in
            selectedSurface = .recents
            isSearchVisible = false
            searchText = ""
            dialNumber = (notification.userInfo?["digits"] as? String) ?? "99999"
            isDialpadPresented = true
            simulateDebugDeleteHold()
        }
        .onReceive(NotificationCenter.default.publisher(for: rotaryDebugCallsOpenDialResultsNotification)) { notification in
            selectedSurface = .recents
            isSearchVisible = false
            searchText = ""
            dialNumber = (notification.userInfo?["digits"] as? String) ?? "9"
            isDialpadPresented = true
            showingDialSearchResults = true
        }
    }

    private var surfaceContent: some View {
        VStack(spacing: 0) {
            switch selectedSurface {
            case .recents:
                recentSurface
            case .contacts:
                contactsSurface
            case .voicemail:
                voicemailSurface
            }
        }
    }

    @ToolbarContentBuilder
    private var surfaceToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            toolbarLeading
        }

        ToolbarItem(placement: .principal) {
            toolbarPrincipal
        }

        ToolbarItem(placement: .topBarTrailing) {
            toolbarTrailing
        }
    }

    @ViewBuilder
    private var toolbarLeading: some View {
        Menu {
            Section("Views") {
                ForEach(availableMenuSurfaces) { surface in
                    Button {
                        RotaryHaptics.selection()
                        selectedSurface = surface
                    } label: {
                        Label(surface.navigationTitle, systemImage: surface.icon)
                    }
                }
            }

            Section("App") {
                Button("Settings", systemImage: "gearshape") {
                    showSettings()
                }
            }
        } label: {
            CallsToolbarIconLabel(systemName: "line.3.horizontal")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var toolbarPrincipal: some View {
        if selectedSurface == .recents {
            CallsRecentsFilterControl(selection: $selectedRecentsFilter)
                .frame(maxWidth: 168)
        } else {
            Color.clear
                .frame(width: 1, height: 1)
        }
    }

    @ViewBuilder
    private var toolbarTrailing: some View {
        switch selectedSurface {
        case .contacts:
            CallsToolbarIconButton(systemName: "plus") {
                showingCreateContact = true
            }
        case .recents, .voicemail:
            CallsToolbarIconButton(systemName: systemImageNameForSearchToolbar) {
                RotaryHaptics.selection()
                showingUnifiedSearch = true
            }
        }
    }

    private var systemImageNameForSearchToolbar: String {
        "magnifyingglass"
    }

    private func refreshCurrentSurface(forceRefresh: Bool) async {
        switch selectedSurface {
        case .recents, .contacts:
            _ = await store.loadCalls(forceRefresh: forceRefresh)
        case .voicemail:
            _ = await store.loadVoicemails(forceRefresh: forceRefresh)
        }
    }

    @ViewBuilder
    private var listSurface: some View {
        switch selectedSurface {
        case .recents:
            recentCallsList
        case .contacts:
            contactsList
        case .voicemail:
            voicemailList
        }
    }

    private var recentSurface: some View {
        VStack(spacing: 0) {
            recentCallsList
        }
    }

    private var contactsSurface: some View {
        VStack(spacing: 0) {
            callsSurfaceHeader(subtitle: contacts.isEmpty ? "People and businesses you reach" : "\(contacts.count) saved")

            if isSearchVisible {
                RotarySearchField(text: $searchText, prompt: searchPrompt)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            contactsList
        }
    }

    private var voicemailSurface: some View {
        VStack(spacing: 0) {
            voicemailList
        }
    }

    private var recentCallsList: some View {
        callsList(
            pagedRecents,
            fullCount: filteredRecents.count,
            emptyTitle: "No calls yet",
            emptyMessage: "Recent calls will show up here.",
            includeAssist: true,
            isLoading: store.isLoadingCalls,
            loadErrorText: store.loadError,
            onLoadMore: {
                recentsVisibleCount += 40
            }
        )
    }

    private var voicemailList: some View {
        Group {
            if RotaryDebugFlags.forceSkeletonPlaceholders {
                RotarySkeletonList(rows: 5)
                    .padding(.top, 4)
            } else if voicemailCalls.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("No voicemail yet")
                        .font(.headline)
                    Text("Your Rotary voicemail, recordings, and summaries will show up here.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if let loadErrorText = store.voicemailLoadError ?? store.loadError,
                       !loadErrorText.isEmpty {
                        Text(loadErrorText)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
            } else {
                List {
                    ForEach(pagedVoicemailCalls) { call in
                        NavigationLink {
                            CallDetailScreen(
                                call: call,
                                allCalls: allCalls,
                                preferredSourceLine: manualDialSourceLine,
                                startManualCall: startManualCall,
                                messagesStore: messagesStore,
                                api: api,
                                tokenProvider: tokenProvider
                            )
                        } label: {
                            VoicemailRow(call: call)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(RotaryTheme.elevatedStroke)
                    }

                    if voicemailCalls.count > pagedVoicemailCalls.count {
                        Button {
                            RotaryHaptics.selection()
                            voicemailVisibleCount += 40
                        } label: {
                            HStack {
                                Spacer()
                                Text("Load More")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RotaryTheme.accent)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.interactively)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func callsList(
        _ calls: [MobileCall],
        fullCount: Int? = nil,
        emptyTitle: String,
        emptyMessage: String,
        includeAssist: Bool,
        isLoading: Bool,
        loadErrorText: String?,
        onLoadMore: (() -> Void)? = nil
    ) -> some View {
        Group {
            if RotaryDebugFlags.forceSkeletonPlaceholders {
                RotarySkeletonList(rows: 6)
                    .padding(.top, 4)
            } else if calls.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text(emptyTitle)
                        .font(.headline)
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if let loadErrorText, !loadErrorText.isEmpty {
                        Text(loadErrorText)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
            } else {
                List {
                    ForEach(calls) { call in
                        NavigationLink {
                            CallDetailScreen(
                                call: call,
                                allCalls: allCalls,
                                preferredSourceLine: manualDialSourceLine,
                                startManualCall: startManualCall,
                                messagesStore: messagesStore,
                                api: api,
                                tokenProvider: tokenProvider
                            )
                        } label: {
                            CompactCallRow(call: call)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if includeAssist && call.shouldShowLiveSteerControls {
                                Button {
                                    openLiveAssist(call)
                                } label: {
                                    Label("Assist", systemImage: "waveform")
                                }
                                .tint(RotaryTheme.accent)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 14, bottom: 2, trailing: 14))
                    }

                    if let fullCount, fullCount > calls.count, let onLoadMore {
                        Button {
                            RotaryHaptics.selection()
                            onLoadMore()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Load More")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RotaryTheme.accent)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.interactively)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var contactsList: some View {
        Group {
            if contacts.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("No contacts yet")
                        .font(.headline)
                    Text("Once you call or text someone from Rotary, they will appear here.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, 24)
            } else {
                ZStack(alignment: .trailing) {
                    List {
                        if searchText.isEmpty {
                            Section {
                                ownerCardRow
                            }

                            ForEach(contactSections) { section in
                                Section(section.letter) {
                                    ForEach(section.contacts) { contact in
                                        contactListRow(contact)
                                    }
                                }
                            }
                        } else {
                            ForEach(contacts) { contact in
                                contactListRow(contact)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollDismissesKeyboard(.interactively)
                    .scrollContentBackground(.hidden)

                    if searchText.isEmpty, !contactSections.isEmpty {
                        contactIndexOverlay
                            .padding(.trailing, 3)
                    }
                }
            }
        }
    }

    private var ownerCardRow: some View {
        HStack(spacing: 12) {
            CallsContactAvatar(title: ownerCardName, size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(ownerCardName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("My Card")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let ownerCardNumber {
                Text(ownerCardNumber)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(RotaryTheme.elevatedStroke)
                        .listRowInsets(EdgeInsets(top: 2, leading: 14, bottom: 2, trailing: 14))
    }

    private func contactListRow(_ contact: CallsContactRow) -> some View {
        NavigationLink {
            ContactDetailScreen(
                contact: contact,
                relatedCalls: store.history(for: contact.phoneNumber),
                preferredSourceLine: contact.sourceLine ?? manualDialSourceLine,
                startManualCall: startManualCall
            )
        } label: {
            HStack(spacing: 12) {
                CallsContactAvatar(title: contact.name, size: 38)

                Text(contact.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
        .listRowSeparatorTint(RotaryTheme.elevatedStroke)
    }

    private var contactIndexOverlay: some View {
        VStack(spacing: 0.5) {
            ForEach(contactSections.map(\.letter), id: \.self) { letter in
                Text(letter)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(RotaryTheme.accent)
                    .frame(width: 16)
            }
        }
        .padding(.vertical, 12)
    }

    private var keypadSurface: some View {
        GeometryReader { proxy in
            let compactHeight = proxy.size.height < 760
            let ultraCompactHeight = proxy.size.height < 690
            let suggestionHeight: CGFloat = ultraCompactHeight ? 76 : 86
            let digitSize: CGFloat = ultraCompactHeight ? 74 : 82
            let gridSpacing: CGFloat = ultraCompactHeight ? 12 : 16
            let callButtonSize: CGFloat = ultraCompactHeight ? 66 : 72

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Text(dialNumber.isEmpty ? " " : dialNumber)
                            .font(.system(size: 38, weight: .regular))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .padding(.horizontal, 24)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .padding(.top, 2)
                    .frame(height: 56)

                    Group {
                        if let primaryKeypadSuggestion {
                            keypadSuggestionCard(primaryKeypadSuggestion)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(maxWidth: ultraCompactHeight ? 300 : 308)
                    .frame(height: suggestionHeight, alignment: .top)
                    .padding(.horizontal, ultraCompactHeight ? 22 : 26)
                    .padding(.top, ultraCompactHeight ? 8 : 10)
                    .padding(.bottom, 8)

                    Spacer(minLength: ultraCompactHeight ? 8 : 14)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 3), spacing: gridSpacing) {
                        ForEach(keypadDigits) { digit in
                            RotaryDialpadDigitButton(digit: digit, size: digitSize) {
                                RotaryHaptics.lightTap()
                                RotaryDialpadTonePlayer.play(digit: digit.primary)
                                dialNumber.append(digit.primary)
                            }
                        }
                    }
                    .frame(maxWidth: 320)
                    .padding(.horizontal, 24)
                    .padding(.top, ultraCompactHeight ? 2 : 8)

                    ZStack {
                        Button {
                            RotaryHaptics.softTap()
                            startManualCall(dialNumber.trimmingCharacters(in: .whitespacesAndNewlines), manualDialSourceLine)
                        } label: {
                            Group {
                                if #available(iOS 26, *) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: callButtonSize, height: callButtonSize)
                                        .glassEffect(.regular.tint(RotaryTheme.callAccent.opacity(0.4)).interactive(), in: .circle)
                                } else {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: callButtonSize, height: callButtonSize)
                                        .background(RotaryTheme.callAccent, in: Circle())
                                }
                            }
                        }
                        .buttonStyle(RotaryPressScaleButtonStyle(pressedScale: 0.92))
                        .disabled(dialNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(dialNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.68 : 1)

                        HStack {
                            Spacer()
                            RotaryRepeatDeleteButton(text: $dialNumber)
                        }
                        .frame(maxWidth: ultraCompactHeight ? 236 : 248)
                    }
                    .padding(.top, ultraCompactHeight ? 10 : 14)
                    .padding(.horizontal, 36)

                    Spacer(minLength: ultraCompactHeight ? 6 : 12)
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(.top, compactHeight ? 6 : 16)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, compactHeight ? 6 : 12))
            }
        }
    }

    private var keypadDestination: some View {
        ZStack {
            RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() })

            keypadSurface
                .safeAreaInset(edge: .top, spacing: 0) {
                    CallsKeypadTopBar {
                        isDialpadPresented = false
                    }
                }
        }
        .navigationDestination(isPresented: $showingDialSearchResults) {
            CallsDialSearchResultsScreen(
                nameSuggestions: dialSearchNameSuggestions,
                numberSuggestions: dialSearchNumberSuggestions,
                selectedNumber: dialNumber,
                fromNumber: manualDialSourceLine,
                selectNumber: { phoneNumber in
                    dialNumber = phoneNumber
                },
                startManualCall: startManualCall
            )
        }
    }

    private func keypadSuggestionCard(_ suggestion: CallsSuggestion) -> some View {
        VStack(spacing: 0) {
            Button {
                RotaryHaptics.selection()
                dialNumber = suggestion.phoneNumber
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: suggestion.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RotaryTheme.accent)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(suggestion.phoneNumber)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if remainingKeypadSuggestionCount > 0 {
                Divider()
                    .padding(.leading, 54)

                Button {
                    RotaryHaptics.selection()
                    showingDialSearchResults = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)

                        Text("Show \(remainingKeypadSuggestionCount) more results")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("rotary.callsShowMoreResultsButton")
            }
        }
        .frame(maxWidth: .infinity)
        .background(CallsPhonePalette.chromeFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CallsPhonePalette.chromeBorder, lineWidth: 1)
        )
    }

    private func simulateDebugDeleteHold() {
        debugDeleteHoldTask?.cancel()
        debugDeleteHoldTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            var intervalMilliseconds = 110
            while !Task.isCancelled && !dialNumber.isEmpty {
                RotaryHaptics.selection()
                dialNumber.removeLast()
                try? await Task.sleep(for: .milliseconds(intervalMilliseconds))
                intervalMilliseconds = max(34, intervalMilliseconds - 12)
            }
        }
    }

    private var searchPrompt: String {
        switch selectedSurface {
        case .contacts:
            return "Search contacts"
        case .voicemail:
            return "Search voicemail"
        case .recents:
            return "Search calls"
        }
    }

    private func normalizedPhone(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func matchesDialQuery(_ query: String, phoneNumber: String, name: String) -> Bool {
        let digitsQuery = keypadDigitsOnly(query)
        guard !digitsQuery.isEmpty else { return false }
        let phoneDigits = keypadDigitsOnly(phoneNumber)
        if phoneDigits.contains(digitsQuery) {
            return true
        }
        return keypadSignature(for: name).contains(digitsQuery)
    }

    private func callsSurfaceHeader(subtitle: String?) -> some View {
        RotaryInlineStatusHeader(subtitle: subtitle)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
    }

    private var isViewingMissedRecents: Bool {
        selectedSurface == .recents && selectedRecentsFilter == .missed
    }

    private func publishMissedViewState() {
        if isViewingMissedRecents {
            acknowledgedMissedNotificationCount = store.missedCallCount
        }
        onViewingMissedCallsChange?(isViewingMissedRecents)
    }

    private func synchronizeMissedNotificationAcknowledgement(with rawCount: Int) {
        if acknowledgedMissedNotificationCount > rawCount {
            acknowledgedMissedNotificationCount = rawCount
        }
        if isViewingMissedRecents {
            acknowledgedMissedNotificationCount = rawCount
        }
    }
}

private enum CallsUnifiedSearchTarget {
    case calls
    case voicemail
}

private struct CallsUnifiedSearchScreen: View {
    let api: RotaryAPIClient
    let tokenProvider: RotaryTokenProvider
    let messagesStore: MessagesStore
    let allCalls: [MobileCall]
    let voicemails: [MobileCall]
    let startManualCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void
    let seeAllResults: (CallsUnifiedSearchTarget) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [MobileCallSearchResultItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var queryFocused: Bool

    private let previewLimit = 4

    private var callResults: [MobileCallSearchResultItem] {
        results.filter { $0.type.lowercased() != "voicemail" }
    }

    private var voicemailResults: [MobileCallSearchResultItem] {
        results.filter { $0.type.lowercased() == "voicemail" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                searchField

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    emptyQueryState
                } else if isLoading && results.isEmpty {
                    RotarySkeletonList(rows: 4, showTimestamp: false)
                } else if results.isEmpty {
                    noResultsState
                } else {
                    if !callResults.isEmpty {
                        section(
                            title: "Calls",
                            count: callResults.count,
                            showSeeAll: callResults.count > previewLimit
                        ) {
                            seeAllResults(.calls)
                            dismiss()
                        } content: {
                            ForEach(Array(callResults.prefix(previewLimit))) { result in
                                NavigationLink {
                                    CallDetailScreen(
                                        call: result.call,
                                        allCalls: allCalls,
                                        preferredSourceLine: result.call.toNumber ?? result.call.fromNumber,
                                        startManualCall: startManualCall,
                                        messagesStore: messagesStore,
                                        api: api,
                                        tokenProvider: tokenProvider
                                    )
                                } label: {
                                    searchResultRow(result)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !voicemailResults.isEmpty {
                        section(
                            title: "Voicemail",
                            count: voicemailResults.count,
                            showSeeAll: voicemailResults.count > previewLimit
                        ) {
                            seeAllResults(.voicemail)
                            dismiss()
                        } content: {
                            ForEach(Array(voicemailResults.prefix(previewLimit))) { result in
                                NavigationLink {
                                    CallDetailScreen(
                                        call: result.call,
                                        allCalls: allCalls,
                                        preferredSourceLine: result.call.toNumber ?? result.call.fromNumber,
                                        startManualCall: startManualCall,
                                        messagesStore: messagesStore,
                                        api: api,
                                        tokenProvider: tokenProvider
                                    )
                                } label: {
                                    searchResultRow(result)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(RotaryBackdrop())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            queryFocused = true
        }
        .task(id: query) {
            await runSearch(query: query)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Search calls and voicemail", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($queryFocused)

            if !query.isEmpty {
                Button {
                    RotaryHaptics.selection()
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(searchFieldBackground)
    }

    @ViewBuilder
    private var searchFieldBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(.white.opacity(0.14)).interactive(), in: .rect(cornerRadius: 22))
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(RotaryTheme.incomingBubble)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
                )
        }
    }

    private var emptyQueryState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Find anything quickly")
                .font(.headline)
            Text("Search by number, contact name, summary, or transcript across calls and voicemail.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var noResultsState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No matching calls")
                .font(.headline)
            Text("Try a different name, number, summary phrase, or transcript keyword.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        count: Int,
        showSeeAll: Bool,
        onSeeAll: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if showSeeAll {
                    Button("See All") {
                        RotaryHaptics.selection()
                        onSeeAll()
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                } else {
                    Text("\(count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(RotaryTheme.secondarySurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
            )
        }
    }

    private func searchResultRow(_ result: MobileCallSearchResultItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(result.call.contactName.isEmpty ? fallbackNumber(for: result.call) : result.call.contactName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(matchFieldLabel(result.matchField))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RotaryTheme.softSurface, in: Capsule())

                Spacer(minLength: 8)

                Text(rotaryCallTimestampLabel(result.call.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            CallsHighlightedPreviewText(
                text: result.preview,
                ranges: result.previewHighlightedRanges
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    private func fallbackNumber(for call: MobileCall) -> String {
        call.contactPhone ?? call.toNumber ?? call.fromNumber ?? "Unknown number"
    }

    private func matchFieldLabel(_ field: String) -> String {
        switch field.lowercased() {
        case "number":
            return "Number"
        case "name":
            return "Name"
        case "summary":
            return "Summary"
        case "transcript":
            return "Transcript"
        default:
            return "Match"
        }
    }

    @MainActor
    private func runSearch(query currentQuery: String) async {
        let trimmedQuery = currentQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            results = []
            isLoading = false
            errorMessage = nil
            return
        }

        // Keep typing responsive by showing an immediate local result set first.
        let instantLocalResults = localFallbackSearch(trimmedQuery)
        results = instantLocalResults
        isLoading = true
        defer { isLoading = false }

        do {
            let payload = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                try await api.searchCalls(token: token, query: trimmedQuery, forceRefresh: false)
            }
            guard query.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery else { return }
            results = payload.results.isEmpty ? instantLocalResults : payload.results
            errorMessage = nil
        } catch is CancellationError {
            // Ignore cancellation from rapid query edits.
        } catch {
            // Fallback to local search when the merged endpoint is unavailable.
            if results.isEmpty {
                results = instantLocalResults
            }
            errorMessage = results.isEmpty ? error.localizedDescription : nil
        }
    }

    private func localFallbackSearch(_ query: String) -> [MobileCallSearchResultItem] {
        let normalizedQuery = query.lowercased()
        var mergedByID: [String: MobileCall] = [:]
        for call in allCalls {
            mergedByID[call.id] = call
        }
        for voicemail in voicemails {
            mergedByID[voicemail.id] = voicemail
        }
        let voicemailIDs = Set(voicemails.map(\.id))

        return mergedByID.values.compactMap { call in
            let haystacks: [(field: String, value: String)] = [
                ("number", call.contactPhone ?? call.toNumber ?? call.fromNumber ?? ""),
                ("name", call.contactName),
                ("summary", call.summary ?? ""),
                ("transcript", call.transcript ?? ""),
            ]

            guard let match = haystacks.first(where: { $0.value.lowercased().contains(normalizedQuery) }) else {
                return nil
            }

            let preview = match.value.isEmpty
                ? (call.summary ?? call.transcript ?? call.contactPhone ?? call.toNumber ?? call.fromNumber ?? "")
                : match.value
            let ranges = localHighlightRanges(in: preview, query: normalizedQuery)

            return MobileCallSearchResultItem(
                type: voicemailIDs.contains(call.id) ? "voicemail" : "call",
                matchField: match.field,
                preview: preview,
                previewHighlightedRanges: ranges,
                call: call
            )
        }
        .sorted { $0.call.createdAt > $1.call.createdAt }
    }

    private func localHighlightRanges(in text: String, query: String) -> [MobilePreviewHighlightRange] {
        guard !query.isEmpty else { return [] }
        let lowercased = text.lowercased()
        guard let range = lowercased.range(of: query) else { return [] }
        let start = lowercased.distance(from: lowercased.startIndex, to: range.lowerBound)
        let end = lowercased.distance(from: lowercased.startIndex, to: range.upperBound)
        return [MobilePreviewHighlightRange(start: start, length: end - start, end: nil)]
    }
}

private struct CallsHighlightedPreviewText: View {
    let text: String
    let ranges: [MobilePreviewHighlightRange]

    var body: some View {
        highlightedText
    }

    private var highlightedText: Text {
        guard !ranges.isEmpty else {
            return Text(text)
        }

        let textCount = text.count
        var cursor = 0
        var highlighted = Text("")

        let orderedRanges = ranges.sorted { $0.start < $1.start }
        for item in orderedRanges {
            let start = max(0, min(item.start, textCount))
            let endCandidate: Int = {
                if let length = item.length {
                    return start + max(length, 0)
                }
                if let end = item.end {
                    return end
                }
                return start
            }()
            let end = max(start, min(endCandidate, textCount))
            guard start < end else { continue }

            if cursor < start {
                highlighted = highlighted + Text(substring(in: cursor ..< start))
            }

            highlighted = highlighted + Text(substring(in: start ..< end))
                .foregroundStyle(RotaryTheme.accent)
                .fontWeight(.semibold)
            cursor = end
        }

        if cursor < textCount {
            highlighted = highlighted + Text(substring(in: cursor ..< textCount))
        }

        return highlighted
    }

    private func substring(in range: Range<Int>) -> String {
        guard let startIndex = index(at: range.lowerBound),
              let endIndex = index(at: range.upperBound) else {
            return ""
        }
        return String(text[startIndex ..< endIndex])
    }

    private func index(at offset: Int) -> String.Index? {
        guard offset >= 0, offset <= text.count else { return nil }
        return text.index(text.startIndex, offsetBy: offset, limitedBy: text.endIndex)
    }
}

private struct RotaryDialpadDigitButton: View {
    let digit: KeypadDigit
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(digit.displayPrimary)
                    .font(.system(size: digit.usesCompactPrimaryFont ? (size < 80 ? 28 : 31) : (size < 80 ? 33 : 37), weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(height: size < 80 ? 34 : 38, alignment: .bottom)

                Text(digit.secondary)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                    .frame(height: 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: size)
            .modifier(RotaryDialpadSurfaceModifier())
        }
        .buttonStyle(RotaryPressScaleButtonStyle(pressedScale: 0.92))
    }
}

private struct CallsKeypadTopBar: View {
    @Environment(\.dismiss) private var dismiss

    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                RotaryHaptics.selection()
                onBack()
                dismiss()
            } label: {
                RotaryGlassIcon(systemName: "chevron.left", size: 14, frameSize: 36)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel("Back")

            Spacer()

            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background(.clear)
    }
}

private struct RotaryDialpadSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(CallsPhonePalette.keyFill, in: Circle())
            .overlay(
                Circle()
                    .stroke(CallsPhonePalette.chromeBorder, lineWidth: 1)
            )
    }
}

private struct CallsToolbarTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        RotaryGlassTextButton(title: title, action: action)
    }
}

private struct CallsToolbarIconLabel: View {
    let systemName: String

    var body: some View {
        RotaryGlassIcon(
            systemName: systemName,
            size: 16,
            frameSize: 36,
            showsBackground: false
        )
    }
}

private struct CallsToolbarIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CallsToolbarIconLabel(systemName: systemName)
        }
        .buttonStyle(RotaryPressScaleButtonStyle(pressedScale: 0.94))
    }
}

private struct CallsRecentsFilterControl: View {
    @Binding var selection: CallsRecentsFilter

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CallsRecentsFilter.allCases) { filter in
                Button {
                    RotaryHaptics.selection()
                    selection = filter
                } label: {
                    Text(filter.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selection == filter ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selection == filter ? RotaryTheme.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct CallsContactAvatar: View {
    let title: String
    let size: CGFloat
    let accent: Color

    init(title: String, size: CGFloat = 34, accent: Color = CallsPhonePalette.contactAvatarFill) {
        self.title = title
        self.size = size
        self.accent = accent
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(accent)

            if initials == "?" {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(.white)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }

    private var initials: String {
        let words = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
        let letters = words.prefix(2).compactMap { word -> String? in
            guard let character = word.first(where: { $0.isLetter || $0.isNumber }) else { return nil }
            return String(character)
        }
        .joined()

        return letters.isEmpty ? "?" : letters.uppercased()
    }
}

private struct CompactCallRow: View {
    let call: MobileCall

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CallsContactAvatar(title: call.contactName, size: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(primaryTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isMissedCall ? RotaryTheme.destructive : Color.primary)
                        .lineLimit(1)

                    if isUnreadVoicemail {
                        Circle()
                            .fill(RotaryTheme.accent)
                            .frame(width: 6, height: 6)
                    }

                    Spacer(minLength: 6)

                    Text(timestampText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Image(systemName: directionIcon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isMissedCall ? RotaryTheme.destructive : .secondary)

                    Text(secondaryLineText)
                        .font(.caption)
                        .foregroundStyle(isMissedCall ? RotaryTheme.destructive.opacity(0.85) : .secondary)
                        .lineLimit(1)
                }

                if let previewText {
                    Text(previewText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 4)
    }

    private var primaryTitle: String {
        let trimmed = call.contactName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallbackNumber : trimmed
    }

    private var directionIcon: String {
        if isMissedCall {
            return "phone.down.fill"
        }
        if call.status.lowercased().contains("outbound") {
            return "phone.arrow.up.right.fill"
        }
        return "phone.arrow.down.left.fill"
    }

    private var secondaryLineText: String {
        callLocationLabel(for: call) ?? fallbackNumber
    }

    private var previewText: String? {
        call.summary?.nonEmptyTrimmed ?? call.transcript?.nonEmptyTrimmed
    }

    private var timestampText: String {
        rotaryCallTimestampLabel(call.createdAt)
    }

    private var fallbackNumber: String {
        call.contactPhone ?? call.toNumber ?? call.fromNumber ?? "Unknown number"
    }

    private var isMissedCall: Bool {
        callIsMissed(call)
    }

    private var isUnreadVoicemail: Bool {
        callIsUnreadVoicemail(call)
    }
}

private struct VoicemailRow: View {
    let call: MobileCall

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CallsContactAvatar(title: call.contactName, size: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(primaryTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)

                    if isUnreadVoicemail {
                        Circle()
                            .fill(RotaryTheme.accent)
                            .frame(width: 6, height: 6)
                    }

                    Spacer(minLength: 6)

                    Text(timestampText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isMissedCall ? RotaryTheme.destructive : .secondary)

                    Text(secondaryLineText)
                        .font(.caption)
                        .foregroundStyle(isMissedCall ? RotaryTheme.destructive.opacity(0.85) : .secondary)
                        .lineLimit(1)
                }

                if let previewLine {
                    Text(previewLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 4)
    }

    private var primaryTitle: String {
        let trimmed = call.contactName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallbackNumber : trimmed
    }

    private var previewLine: String? {
        if let summary = call.summary?.nonEmptyTrimmed {
            return summary
        }
        if let transcript = call.transcript?.nonEmptyTrimmed {
            return transcript
        }
        return nil
    }

    private var fallbackNumber: String {
        call.contactPhone ?? call.toNumber ?? call.fromNumber ?? "Unknown number"
    }

    private var titleColor: Color {
        if isMissedCall || voicemailContextLabel(for: call).localizedCaseInsensitiveContains("spam") {
            return RotaryTheme.destructive
        }
        return .primary
    }

    private var secondaryLineText: String {
        let location = callLocationLabel(for: call) ?? fallbackNumber
        let duration = call.durationSeconds.flatMap { value in
            value > 0 ? formatDuration(value) : nil
        }
        let parts = [location, duration]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.joined(separator: " • ")
    }

    private var timestampText: String {
        rotaryCallTimestampLabel(call.createdAt)
    }

    private var isMissedCall: Bool {
        callIsMissed(call)
    }

    private var isUnreadVoicemail: Bool {
        callIsUnreadVoicemail(call)
    }
}

private func callIsMissed(_ call: MobileCall) -> Bool {
    call.status.lowercased().contains("missed")
        || call.livePhase == .noAnswer
}

private func callIsUnreadVoicemail(_ call: MobileCall) -> Bool {
    call.hasPlayableVoicemailRecording && call.readAt == nil
}

private func callLocationLabel(for call: MobileCall) -> String? {
    if let cnamLocation = cnamLocationLabel(for: call) {
        return cnamLocation
    }

    return rotaryAreaLabel(for: call.contactPhone ?? call.toNumber ?? call.fromNumber)
}

private func cnamLocationLabel(for call: MobileCall) -> String? {
    let payload = call.intakePayload

    let directKeys = [
        "cnam_location",
        "caller_location",
        "location_label",
        "location",
    ]

    for key in directKeys {
        if let value = payload[key]?.stringValue, !value.isEmpty {
            return value
        }
    }

    let city = payload["caller_city"]?.stringValue ?? payload["city"]?.stringValue
    let state = payload["caller_state"]?.stringValue ?? payload["state"]?.stringValue

    switch (city, state) {
    case let (city?, state?):
        return "\(city), \(state)"
    case let (city?, nil):
        return city
    case let (nil, state?):
        return state
    default:
        return nil
    }
}

private struct RotaryRepeatDeleteButton: View {
    @Binding var text: String

    @State private var repeatTask: Task<Void, Never>?
    @State private var isPressing = false
    @State private var repeatedDuringPress = false

    var body: some View {
        Image(systemName: "delete.left.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(text.isEmpty ? Color.primary.opacity(0.72) : Color.primary)
            .frame(width: 48, height: 34)
            .background(
                CallsPhonePalette.keyFill.opacity(text.isEmpty ? 0.9 : 1),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(CallsPhonePalette.chromeBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        beginPressIfNeeded()
                    }
                    .onEnded { _ in
                        endPress()
                    }
            )
            .accessibilityAddTraits(.isButton)
            .onDisappear {
                cancelRepeat()
            }
    }

    private func deleteSingleCharacter() {
        guard !text.isEmpty else { return }
        RotaryHaptics.selection()
        text.removeLast()
    }

    private func beginPressIfNeeded() {
        guard !isPressing else { return }
        isPressing = true
        repeatedDuringPress = false
        repeatTask?.cancel()
        repeatTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, isPressing else { return }
            var intervalMilliseconds = 110
            while !Task.isCancelled && !text.isEmpty {
                repeatedDuringPress = true
                RotaryHaptics.selection()
                text.removeLast()
                try? await Task.sleep(for: .milliseconds(intervalMilliseconds))
                intervalMilliseconds = max(34, intervalMilliseconds - 12)
            }
        }
    }

    private func endPress() {
        let shouldDeleteSingle = isPressing && !repeatedDuringPress
        isPressing = false
        cancelRepeat()
        if shouldDeleteSingle {
            deleteSingleCharacter()
        }
        repeatedDuringPress = false
    }

    private func cancelRepeat() {
        repeatTask?.cancel()
        repeatTask = nil
    }
}

private enum RotaryDialpadTonePlayer {
    private static let keyTapSoundID: SystemSoundID = 1104

    static func play(digit _: String) {
        AudioServicesPlaySystemSound(keyTapSoundID)
    }
}

private struct CallsDialSearchResultsScreen: View {
    let nameSuggestions: [CallsSuggestion]
    let numberSuggestions: [CallsSuggestion]
    let selectedNumber: String
    let fromNumber: String?
    let selectNumber: (String) -> Void
    let startManualCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if nameSuggestions.isEmpty && numberSuggestions.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No matching results")
                            .font(.headline)
                        Text("Try another number or name.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    .listRowBackground(Color.clear)
                }
            }

            if !nameSuggestions.isEmpty {
                Section {
                    ForEach(nameSuggestions) { suggestion in
                        suggestionRow(suggestion)
                    }
                }
            }

            if !numberSuggestions.isEmpty {
                Section {
                    ForEach(numberSuggestions) { suggestion in
                        suggestionRow(suggestion)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(RotaryBackdrop())
    }

    private func suggestionRow(_ suggestion: CallsSuggestion) -> some View {
        HStack(spacing: 12) {
            Button {
                RotaryHaptics.selection()
                selectNumber(suggestion.phoneNumber)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: suggestion.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RotaryTheme.accent)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(suggestion.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(suggestion.phoneNumber)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button {
                RotaryHaptics.softTap()
                startManualCall(suggestion.phoneNumber, suggestion.sourceLine ?? fromNumber)
            } label: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RotaryTheme.accent)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

private struct CallsDetailCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(CallsPhonePalette.chromeFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(CallsPhonePalette.chromeBorder, lineWidth: 1)
            )
    }
}

private struct CallsContactActionButton: View {
    let title: String
    let systemImage: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(accent, in: Circle())

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(CallsPhonePalette.chromeFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(CallsPhonePalette.chromeBorder, lineWidth: 1)
            )
        }
        .buttonStyle(RotaryPressScaleButtonStyle(pressedScale: 0.97))
    }
}

private struct ContactDetailScreen: View {
    let contact: CallsContactRow
    let relatedCalls: [MobileCall]
    let preferredSourceLine: String?
    let startManualCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 14) {
                    CallsContactAvatar(title: contact.name, size: 110)

                    VStack(spacing: 6) {
                        Text(contact.name)
                            .font(.system(size: 32, weight: .bold))
                            .multilineTextAlignment(.center)

                        Text(contact.phoneNumber)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                HStack(spacing: 12) {
                    CallsContactActionButton(
                        title: "Call",
                        systemImage: "phone.fill",
                        accent: RotaryTheme.callAccent
                    ) {
                        RotaryHaptics.softTap()
                        startManualCall(contact.phoneNumber, preferredSourceLine)
                    }
                }

                CallsDetailCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Contact")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("mobile")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(contact.phoneNumber)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }

                if let latestPreview = contact.latestPreview, !latestPreview.isEmpty {
                    CallsDetailCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Latest")
                                .font(.headline)
                            Text(latestPreview)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !relatedCalls.isEmpty {
                    CallsDetailCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Recent Calls")
                                .font(.headline)

                            ForEach(Array(relatedCalls.prefix(12).enumerated()), id: \.element.id) { index, call in
                                if index > 0 {
                                    Divider()
                                }
                                CompactCallRow(call: call)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(RotaryBackdrop())
        .navigationTitle(contact.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum CallDetailSegment: String, CaseIterable, Identifiable {
    case details = "Details"
    case voicemails = "Voicemails"

    var id: String { rawValue }
}

private enum CallHistoryBucket: String, CaseIterable, Identifiable {
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
    case lastMonth = "Last Month"
    case thisYear = "This Year"
    case earlier = "Earlier"

    var id: String { rawValue }
}

struct CallDetailScreen: View {
    let call: MobileCall
    let allCalls: [MobileCall]
    let preferredSourceLine: String?
    let startManualCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void
    let messagesStore: MessagesStore
    let api: RotaryAPIClient
    let tokenProvider: RotaryTokenProvider

    @State private var player = RotaryAudioPlayer()
    @State private var callDetailPayload: MobileCallDetailPayload?
    @State private var voicemailDetailPayload: MobileVoicemailDetailPayload?
    @State private var loadError: String?
    @State private var showingCreateContact = false
    @State private var showingMessageSheet = false
    @State private var showingTranscriptReader = false
    @State private var transcriptReaderTitle = ""
    @State private var transcriptReaderBody = ""
    @State private var showingCallHistory = false
    @State private var selectedSegment: CallDetailSegment = .details
    @State private var showingBlockConfirmation = false
    @State private var actionNotice: String?

    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    private var displayCall: MobileCall {
        voicemailDetailPayload?.voicemail ?? callDetailPayload?.call ?? call
    }

    private var primaryNumber: String? {
        normalizedPhone(displayCall.contactPhone ?? displayCall.toNumber ?? displayCall.fromNumber)
    }

    private var displayNumber: String {
        primaryNumber ?? "No number available"
    }

    private var composeFromNumber: String? {
        let preferred = normalizedPhone(preferredSourceLine)
        let from = normalizedPhone(displayCall.fromNumber)
        let to = normalizedPhone(displayCall.toNumber)
        guard let primaryNumber else {
            return preferred ?? from ?? to
        }

        if from == primaryNumber {
            return preferred ?? to ?? from
        }
        if to == primaryNumber {
            return preferred ?? from ?? to
        }
        return preferred ?? from ?? to
    }

    private var displayName: String {
        let trimmed = displayCall.contactName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased().contains("unknown") {
            return "UNKNOWN"
        }
        return trimmed
    }

    private var headerDisplayName: String {
        let normalized = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "Unknown" }
        if normalized == "UNKNOWN" {
            return "Unknown"
        }
        let firstWord = normalized.split(separator: " ").first.map(String.init)
        return firstWord ?? normalized
    }

    private var isUnknownContact: Bool {
        displayName == "UNKNOWN" || displayCall.contactId == nil
    }

    private var contactEmail: String? {
        let keys = ["email", "contact_email", "contactEmail", "caller_email"]
        for key in keys {
            if case let .string(value)? = displayCall.intakePayload[key] {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private var relatedCalls: [MobileCall] {
        if let payload = callDetailPayload, !payload.relatedCalls.isEmpty {
            return payload.relatedCalls
        }
        if let payload = voicemailDetailPayload, !payload.relatedCalls.isEmpty {
            return payload.relatedCalls
        }
        return allCalls.filter { matchesContact($0) }
    }

    private var contactCallHistory: [MobileCall] {
        var merged = [displayCall] + relatedCalls + allCalls.filter { matchesContact($0) }
        var seen = Set<String>()
        merged = merged.filter { seen.insert($0.id).inserted }
        return merged.sorted { left, right in
            (parseDate(left.createdAt) ?? .distantPast) > (parseDate(right.createdAt) ?? .distantPast)
        }
    }

    private var voicemailHistory: [MobileCall] {
        contactCallHistory.filter { $0.isVoicemailConversation || $0.hasPlayableVoicemailRecording }
    }

    private var voicemailBuckets: [(bucket: CallHistoryBucket, calls: [MobileCall])] {
        let grouped = Dictionary(grouping: voicemailHistory) { call -> CallHistoryBucket in
            guard let date = parseDate(call.createdAt) else { return .earlier }
            return bucket(for: date)
        }
        let order: [CallHistoryBucket] = [.thisWeek, .lastWeek, .lastMonth, .thisYear, .earlier]
        return order.compactMap { key in
            guard let calls = grouped[key], !calls.isEmpty else { return nil }
            return (
                bucket: key,
                calls: calls.sorted { left, right in
                    (parseDate(left.createdAt) ?? .distantPast) > (parseDate(right.createdAt) ?? .distantPast)
                }
            )
        }
    }

    private var detailsRows: [(title: String, value: String)] {
        var rows: [(title: String, value: String)] = []
        rows.append(("Direction", directionTitle))
        rows.append(("Status", statusLabel(for: displayCall)))
        if let durationText {
            rows.append(("Length", durationText))
        } else {
            rows.append(("Length", "Missed"))
        }
        if let date = parseDate(displayCall.createdAt) {
            rows.append(("Timestamp", date.formatted(.dateTime.weekday(.wide).month().day().hour().minute())))
        }
        if let source = normalizedPhone(displayCall.fromNumber), !source.isEmpty {
            rows.append(("From", source))
        }
        if let destination = normalizedPhone(displayCall.toNumber), !destination.isEmpty {
            rows.append(("To", destination))
        }
        return rows
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(displayNumber)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                primaryActionRow
                segmentControl
                segmentContent
                mediaAndInsights
                contactActions

                if let loadError, !loadError.isEmpty {
                    RotaryGlassCard {
                        Text(loadError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
        .background(RotaryBackdrop())
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    RotaryGlassIcon(systemName: "chevron.left", size: 13, frameSize: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }

            ToolbarItem(placement: .principal) {
                RotaryConversationThreadHeader(
                    title: headerDisplayName,
                    avatarSize: 44
                )
                .accessibilityLabel(displayName)
            }

            ToolbarItem(placement: .topBarTrailing) {
                RotaryGlassIconButton(systemName: "clock.arrow.circlepath") {
                    RotaryHaptics.selection()
                    showingCallHistory = true
                }
            }
        }
        .sheet(isPresented: $showingCreateContact) {
            CallsCreateContactSheet(
                initialName: isUnknownContact ? nil : displayName,
                initialPhoneNumber: primaryNumber,
                api: api,
                tokenProvider: tokenProvider
            )
        }
        .sheet(isPresented: $showingMessageSheet) {
            if let primaryNumber, let composeFromNumber {
                ProxyMessageSheet(
                    fromNumber: composeFromNumber,
                    initialToNumber: primaryNumber,
                    messagesStore: messagesStore
                )
            }
        }
        .navigationDestination(isPresented: $showingTranscriptReader) {
            CallTranscriptReaderScreen(
                title: transcriptReaderTitle,
                transcript: transcriptReaderBody
            )
        }
        .navigationDestination(isPresented: $showingCallHistory) {
            CallHistoryTimelineScreen(
                displayName: displayName,
                phoneNumber: primaryNumber,
                calls: contactCallHistory,
                preferredSourceLine: preferredSourceLine,
                startManualCall: startManualCall
            )
        }
        .confirmationDialog(
            "Block this contact?",
            isPresented: $showingBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button("Block Contact", role: .destructive) {
                blockCurrentContact()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Calls from this number will be flagged as blocked on this device.")
        }
        .alert("Contact Action", isPresented: Binding(
            get: { actionNotice != nil },
            set: { if !$0 { actionNotice = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionNotice ?? "")
        }
        .task {
            await loadDetails()
        }
        .onDisappear {
            player.stopAndResetAudioRoute()
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 10) {
            CallsContactAvatar(title: displayName, size: 120)

            Text(displayName)
                .font(.title2.weight(.bold))
                .tracking(isUnknownContact ? 1.2 : 0)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(displayNumber)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var primaryActionRow: some View {
        HStack(spacing: 12) {
            CallDetailPrimaryAction(
                title: "Message",
                systemImage: "bubble.left.fill",
                isEnabled: primaryNumber != nil && composeFromNumber != nil,
                action: {
                    guard primaryNumber != nil, composeFromNumber != nil else {
                        actionNotice = "No available line to send a message from."
                        return
                    }
                    RotaryHaptics.softTap()
                    showingMessageSheet = true
                }
            )

            CallDetailPrimaryAction(
                title: "Call",
                systemImage: "phone.fill",
                isEnabled: primaryNumber != nil,
                action: {
                    guard let primaryNumber else { return }
                    RotaryHaptics.softTap()
                    startManualCall(primaryNumber, preferredSourceLine)
                }
            )

            CallDetailPrimaryAction(
                title: "Email",
                systemImage: "envelope.fill",
                isEnabled: contactEmail != nil,
                action: {
                    guard let contactEmail else { return }
                    openEmailComposer(contactEmail)
                }
            )
        }
    }

    private var segmentControl: some View {
        HStack(spacing: 8) {
            ForEach(CallDetailSegment.allCases) { segment in
                Button {
                    RotaryHaptics.selection()
                    selectedSegment = segment
                } label: {
                    Text(segment.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedSegment == segment ? .black.opacity(0.86) : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedSegment == segment
                                ? RotaryTheme.accent
                                : RotaryTheme.softSurface.opacity(0.8),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var segmentContent: some View {
        switch selectedSegment {
        case .details:
            RotaryGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.subheadline.weight(.semibold))

                    ForEach(detailsRows, id: \.title) { row in
                        HStack(spacing: 12) {
                            Text(row.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 82, alignment: .leading)

                            Text(row.value)
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Spacer(minLength: 0)
                        }
                    }

                    if !contactCallHistory.isEmpty {
                        Button {
                            showingCallHistory = true
                        } label: {
                            HStack(spacing: 8) {
                                Text("Open Call History")
                                    .font(.subheadline.weight(.semibold))
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(RotaryTheme.softSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case .voicemails:
            if voicemailBuckets.isEmpty {
                RotaryGlassCard {
                    Text("No voicemail activity yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                RotaryGlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(voicemailBuckets, id: \.bucket) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.bucket.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(section.calls) { sectionCall in
                                    CallDetailTimelineRow(
                                        call: sectionCall,
                                        preferredSourceLine: preferredSourceLine
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var mediaAndInsights: some View {
        if let recordingSectionTitle {
            RotaryGlassCard {
                Text(recordingSectionTitle)
                    .font(.subheadline.weight(.semibold))
                if let url = playableRecordingURL, displayCall.shouldShowPlaybackControl {
                    VoicemailPlaybackCard(
                        player: player,
                        url: url,
                        title: recordingSectionTitle,
                        fallbackDurationSeconds: displayCall.durationSeconds
                    )
                } else if let playbackStatusMessage = displayCall.playbackStatusMessage {
                    Text(playbackStatusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }

        if let summary = displayCall.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            RotaryGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Summary")
                        .font(.subheadline.weight(.semibold))
                    Text(summary)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .lineLimit(5)
                }
            }
        }

        if let transcript = displayCall.transcript?.trimmingCharacters(in: .whitespacesAndNewlines), !transcript.isEmpty {
            RotaryGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Transcript")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button("Expand") {
                            transcriptReaderTitle = "Transcript"
                            transcriptReaderBody = transcript
                            showingTranscriptReader = true
                        }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.plain)
                    }
                    Text(transcript)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .lineLimit(6)
                }
            }
        }
    }

    private var contactActions: some View {
        RotaryGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Contact Actions")
                    .font(.subheadline.weight(.semibold))

                CallDetailActionRowButton(
                    title: isUnknownContact ? "Add Name" : "Edit Name",
                    systemImage: "person.text.rectangle",
                    action: {
                        showingCreateContact = true
                    }
                )

                ShareLink(item: contactShareText) {
                    CallDetailActionRowButtonLabel(
                        title: "Share Contact",
                        systemImage: "square.and.arrow.up"
                    )
                }
                .buttonStyle(.plain)

                CallDetailActionRowButton(
                    title: "Create New Contact",
                    systemImage: "person.crop.circle.badge.plus",
                    action: {
                        showingCreateContact = true
                    }
                )

                CallDetailActionRowButton(
                    title: "Add to Existing Contact",
                    systemImage: "person.2.badge.gearshape",
                    action: {
                        openExistingContacts()
                    }
                )

                CallDetailActionRowButton(
                    title: "Block Contact",
                    systemImage: "hand.raised.fill",
                    role: .destructive,
                    action: {
                        showingBlockConfirmation = true
                    }
                )
            }
        }
    }

    private var contactShareText: String {
        let name = displayName
        let number = primaryNumber ?? "Unavailable"
        return "\(name)\n\(number)"
    }

    private func openEmailComposer(_ email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed),
              let url = URL(string: "mailto:\(encoded)") else {
            return
        }
        openURL(url)
    }

    private func openExistingContacts() {
        if let url = URL(string: "addressbook://"), UIApplication.shared.canOpenURL(url) {
            openURL(url)
            return
        }
        actionNotice = "Open Contacts and add this number to an existing person."
    }

    private func blockCurrentContact() {
        guard let primaryNumber else {
            actionNotice = "No number available to block."
            return
        }

        let key = "rotary.blockedNumbers"
        var blocked = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        blocked.insert(primaryNumber)
        UserDefaults.standard.set(Array(blocked).sorted(), forKey: key)
        actionNotice = "\(primaryNumber) was added to your blocked list on this device."
    }

    private func matchesContact(_ candidate: MobileCall) -> Bool {
        if let displayContactId = displayCall.contactId,
           let candidateContactId = candidate.contactId,
           displayContactId == candidateContactId {
            return true
        }

        guard let reference = canonicalPhone(primaryNumber),
              let candidateNumber = canonicalPhone(
                normalizedPhone(candidate.contactPhone ?? candidate.toNumber ?? candidate.fromNumber)
              ) else {
            return false
        }
        return reference == candidateNumber
    }

    private func canonicalPhone(_ value: String?) -> String? {
        guard let value else { return nil }
        let digits = value.filter(\.isNumber)
        if digits.isEmpty { return nil }
        if digits.count == 11, digits.first == "1" {
            return String(digits.dropFirst())
        }
        return digits
    }

    private func bucket(for date: Date) -> CallHistoryBucket {
        let calendar = Calendar.current
        let now = Date()
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return .earlier
        }

        if thisWeek.contains(date) {
            return .thisWeek
        }

        if let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start),
           let lastWeek = calendar.dateInterval(of: .weekOfYear, for: lastWeekStart),
           lastWeek.contains(date) {
            return .lastWeek
        }

        if let thisMonth = calendar.dateInterval(of: .month, for: now),
           let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonth.start),
           let lastMonth = calendar.dateInterval(of: .month, for: lastMonthStart),
           lastMonth.contains(date) {
            return .lastMonth
        }

        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return .thisYear
        }

        return .earlier
    }

    private var directionTitle: String {
        let status = displayCall.status.lowercased()
        if status.contains("missed") {
            return "Missed"
        }
        if normalizedPhone(displayCall.fromNumber) == normalizedPhone(preferredSourceLine) {
            return "Outgoing"
        }
        if status.contains("outbound") {
            return "Outgoing"
        }
        return "Incoming"
    }

    private var durationText: String? {
        guard let durationSeconds = displayCall.durationSeconds, durationSeconds > 0 else {
            return nil
        }
        return formatDuration(durationSeconds)
    }

    private var playableRecordingURL: URL? {
        guard let url = api.resolveMediaURL(displayCall.recordingUrl),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            return nil
        }
        return url
    }

    private var recordingSectionTitle: String? {
        displayCall.playbackSectionTitle
    }

    private func parseDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }

    private func normalizedPhone(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func loadDetails() async {
        do {
            if displayCall.shouldLoadVoicemailDetailRoute {
                voicemailDetailPayload = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                    try await api.voicemailDetail(token: token, voicemailId: call.id)
                }
            } else {
                callDetailPayload = try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                    try await api.callDetail(token: token, callId: call.id)
                }
            }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct CallDetailPrimaryAction: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isEnabled ? RotaryTheme.accent : Color.secondary.opacity(0.5))
                    .frame(width: 38, height: 38)
                    .background(RotaryTheme.softSurface, in: Circle())

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RotaryTheme.secondarySurface.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct CallDetailActionRowButtonLabel: View {
    let title: String
    let systemImage: String
    var role: ButtonRole? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(role == .destructive ? .red : .secondary)
                .frame(width: 18)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(role == .destructive ? .red : .primary)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
}

private struct CallDetailActionRowButton: View {
    let title: String
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            CallDetailActionRowButtonLabel(title: title, systemImage: systemImage, role: role)
        }
        .buttonStyle(.plain)
    }
}

private struct CallDetailTimelineRow: View {
    let call: MobileCall
    let preferredSourceLine: String?

    private var directionTitle: String {
        let normalizedStatus = call.status.lowercased()
        if normalizedStatus.contains("missed") {
            return "Missed"
        }
        if normalizedPhone(call.fromNumber) == normalizedPhone(preferredSourceLine) || normalizedStatus.contains("outbound") {
            return "Outgoing"
        }
        return "Incoming"
    }

    private var detailText: String {
        if let duration = call.durationSeconds, duration > 0 {
            return "\(directionTitle) • \(formatDuration(duration))"
        }
        return "\(directionTitle) • Missed"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconTint)
                .frame(width: 18, height: 18)
                .background(RotaryTheme.softSurface, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(detailText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(rotaryCallTimestampLabel(call.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var iconName: String {
        switch directionTitle {
        case "Missed":
            return "phone.down.fill"
        case "Outgoing":
            return "arrow.up.right"
        default:
            return "arrow.down.left"
        }
    }

    private var iconTint: Color {
        directionTitle == "Missed" ? .red : RotaryTheme.accent
    }

    private func normalizedPhone(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct CallHistoryTimelineScreen: View {
    let displayName: String
    let phoneNumber: String?
    let calls: [MobileCall]
    let preferredSourceLine: String?
    let startManualCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(calls) { call in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: directionIcon(for: call))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(directionColor(for: call))

                        Text(directionLabel(for: call))
                            .font(.subheadline.weight(.semibold))

                        Spacer(minLength: 0)

                        if let duration = call.durationSeconds, duration > 0 {
                            Text(formatDuration(duration))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Missed")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(rotaryCallTimestampLabel(call.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RotaryBackdrop())
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    RotaryGlassIcon(systemName: "chevron.left", size: 13, frameSize: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }

            ToolbarItem(placement: .principal) {
                RotaryConversationThreadHeader(
                    title: headerDisplayName,
                    avatarSize: 44
                )
                .accessibilityLabel(displayName)
            }

            if let phoneNumber {
                ToolbarItem(placement: .topBarTrailing) {
                    RotaryGlassIconButton(systemName: "phone.fill") {
                        startManualCall(phoneNumber, preferredSourceLine)
                    }
                }
            }
        }
    }

    private var headerDisplayName: String {
        let normalized = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "Unknown" }
        if normalized == "UNKNOWN" {
            return "Unknown"
        }
        let firstWord = normalized.split(separator: " ").first.map(String.init)
        return firstWord ?? normalized
    }

    private func directionLabel(for call: MobileCall) -> String {
        let status = call.status.lowercased()
        if status.contains("missed") {
            return "Missed"
        }
        let source = call.fromNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        let owner = preferredSourceLine?.trimmingCharacters(in: .whitespacesAndNewlines)
        if source == owner || status.contains("outbound") {
            return "Outgoing"
        }
        return "Incoming"
    }

    private func directionIcon(for call: MobileCall) -> String {
        switch directionLabel(for: call) {
        case "Missed":
            return "phone.down.fill"
        case "Outgoing":
            return "arrow.up.right"
        default:
            return "arrow.down.left"
        }
    }

    private func directionColor(for call: MobileCall) -> Color {
        directionLabel(for: call) == "Missed" ? .red : RotaryTheme.accent
    }
}

private struct CallDetailQuickActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RotaryTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(RotaryTheme.softSurface, in: Circle())
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CallDetailMetaChip: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(RotaryTheme.softSurface, in: Capsule(style: .continuous))
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
    }
}

private struct CallTranscriptReaderScreen: View {
    let title: String
    let transcript: String

    @State private var shareURL: URL?

    var body: some View {
        ScrollView {
            Text(transcript)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
        }
        .background(RotaryBackdrop())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    UIPasteboard.general.string = transcript
                    RotaryHaptics.selection()
                } label: {
                    Image(systemName: "doc.on.doc")
                }

                if let shareURL {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            shareURL = createShareFileURL()
        }
    }

    private func createShareFileURL() -> URL? {
        let directory = FileManager.default.temporaryDirectory
        let slug = title
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
        let fileURL = directory.appendingPathComponent("\(slug)-\(UUID().uuidString).txt")
        do {
            try transcript.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
}

private struct VoicemailPlaybackCard: View {
    @Bindable var player: RotaryAudioPlayer
    let url: URL
    let title: String
    let fallbackDurationSeconds: Int?

    private var effectiveDuration: Double {
        max(player.duration, Double(max(fallbackDurationSeconds ?? 0, 0)))
    }

    private var clampedCurrentTime: Double {
        min(max(player.currentTime, 0), max(effectiveDuration, 0))
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    RotaryHaptics.lightTap()
                    player.togglePlayback()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(RotaryTheme.accent, in: Circle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(player.isPlaying ? "Playing" : "Ready to play")
                        .font(.subheadline.weight(.semibold))
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    RotaryHaptics.selection()
                    player.toggleAudioRoute()
                } label: {
                    Image(systemName: player.audioRoute.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(RotaryTheme.softSurface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.audioRoute.title)

                Text(timerText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { clampedCurrentTime },
                    set: { player.seek(to: min($0, max(effectiveDuration, 0))) }
                ),
                in: 0 ... max(effectiveDuration, 1)
            )
            .tint(RotaryTheme.accent)
        }
        .task {
            player.load(url: url)
        }
        .onDisappear {
            player.stop()
        }
    }

    private var timerText: String {
        let current = Int(clampedCurrentTime.rounded())
        let total = Int(max(effectiveDuration, 0).rounded())
        if total <= 0 {
            return "Loading…"
        }
        return "\(formatDuration(current)) / \(formatDuration(total))"
    }

    private var subtitleText: String {
        if let fallbackDurationSeconds, fallbackDurationSeconds > 0 {
            return "\(title) • \(formatDuration(fallbackDurationSeconds))"
        }
        return title
    }
}

private func keypadDigitsOnly(_ value: String) -> String {
    value.filter(\.isNumber)
}

private func keypadSignature(for value: String) -> String {
    let mapping: [Character: Character] = [
        "a": "2", "b": "2", "c": "2",
        "d": "3", "e": "3", "f": "3",
        "g": "4", "h": "4", "i": "4",
        "j": "5", "k": "5", "l": "5",
        "m": "6", "n": "6", "o": "6",
        "p": "7", "q": "7", "r": "7", "s": "7",
        "t": "8", "u": "8", "v": "8",
        "w": "9", "x": "9", "y": "9", "z": "9",
    ]

    return value.lowercased().compactMap { mapping[$0] }.map(String.init).joined()
}

private func statusLabel(for call: MobileCall) -> String {
    call.status.replacingOccurrences(of: "_", with: " ").capitalized
}

private func formatDuration(_ seconds: Int) -> String {
    guard seconds > 0 else { return "0:00" }
    let minutes = seconds / 60
    let remainder = seconds % 60
    return "\(minutes):" + String(format: "%02d", remainder)
}

private func rotaryCallTimestampLabel(_ value: String) -> String {
    guard let date = ISO8601DateFormatter().date(from: value) else {
        return ""
    }
    return RotaryDateFormatting.relativeTimestamp(for: date)
}

private func voicemailContextLabel(for call: MobileCall) -> String {
    if let summary = call.summary?.nonEmptyTrimmed {
        return summary
    }
    if let transcript = call.transcript?.nonEmptyTrimmed {
        return transcript
    }
    if call.contactName.localizedCaseInsensitiveContains("spam") {
        return "Potential Spam"
    }
    if let areaLabel = rotaryAreaLabel(for: call.contactPhone ?? call.toNumber ?? call.fromNumber) {
        return areaLabel
    }
    return call.contactPhone ?? call.toNumber ?? call.fromNumber ?? "Unknown number"
}

private func rotaryAreaLabel(for value: String?) -> String? {
    guard let value else { return nil }

    let digits = value.filter(\.isNumber)
    let normalizedDigits: String
    if digits.count == 11, digits.first == "1" {
        normalizedDigits = String(digits.dropFirst())
    } else {
        normalizedDigits = digits
    }

    guard normalizedDigits.count >= 10 else { return nil }
    let areaCode = String(normalizedDigits.prefix(3))

    let labels: [String: String] = [
        "213": "Los Angeles, CA",
        "310": "West Los Angeles, CA",
        "323": "Los Angeles, CA",
        "415": "San Francisco, CA",
        "424": "West Los Angeles, CA",
        "442": "North County, CA",
        "480": "Mesa, AZ",
        "562": "Long Beach, CA",
        "619": "San Diego, CA",
        "626": "Pasadena, CA",
        "657": "Anaheim, CA",
        "714": "Anaheim, CA",
        "760": "Inland Empire, CA",
        "858": "San Diego, CA",
        "909": "Inland Empire, CA",
        "949": "Orange County, CA",
        "951": "Temecula, CA",
    ]

    return labels[areaCode]
}

private struct CallsCreateContactSheet: View {
    let initialName: String?
    let initialPhoneNumber: String?
    let api: RotaryAPIClient
    let tokenProvider: RotaryTokenProvider

    var body: some View {
        RotaryContactEditorScreen(
            title: "New Contact",
            initialDraft: initialDraft,
            onSave: { draft in
                try await withAuthorizedRetry(tokenProvider: tokenProvider) { token in
                    try await api.createContact(
                        token: token,
                        name: draft.resolvedName,
                        phoneNumber: draft.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                        email: draft.email.nonEmptyTrimmed,
                        company: draft.company.nonEmptyTrimmed,
                        fullAddress: draft.fullAddress.nonEmptyTrimmed,
                        avatarURL: draft.avatarDataURL
                    )
                }
                .contact
            }
        )
    }

    private var initialDraft: RotaryContactDraft {
        let parts = (initialName ?? "")
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)

        return RotaryContactDraft(
            contactId: nil,
            firstName: parts.first.map(String.init) ?? "",
            lastName: parts.count > 1 ? String(parts[1]) : "",
            company: "",
            phoneNumber: initialPhoneNumber ?? "",
            email: "",
            fullAddress: "",
            avatarDataURL: nil
        )
    }
}

private struct CallsCreateContactFieldGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .textInputAutocapitalization(.words)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 58)
        .background(CallsPhonePalette.chromeFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CallsPhonePalette.chromeBorder, lineWidth: 1)
        )
    }
}

private extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
