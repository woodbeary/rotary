import SwiftUI

private enum CallsSurface: String, CaseIterable, Identifiable {
    case keypad = "Keypad"
    case recents = "Recents"
    case contacts = "Contacts"
    case voicemail = "Voicemail"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .keypad:
            return "circle.grid.3x3"
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
        case .keypad:
            return "Keypad"
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
    let api: RotaryAPIClient
    let tokenProvider: RotaryTokenProvider
    let showSettings: () -> Void
    let startCall: (_ call: MobileCall) -> Void
    let startManualCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void
    let openLiveAssist: (_ call: MobileCall) -> Void
    let onMissedCallCountChange: ((Int) -> Void)?

    @State private var selectedSurface: CallsSurface = .recents
    @State private var selectedRecentsFilter: CallsRecentsFilter = .all
    @State private var dialNumber = ""
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @State private var showingCreateContact = false

    init(
        bootstrap: MobileBootstrapReadyState,
        store: CallsStore,
        api: RotaryAPIClient,
        tokenProvider: @escaping RotaryTokenProvider,
        showSettings: @escaping () -> Void,
        startCall: @escaping (_ call: MobileCall) -> Void,
        startManualCall: @escaping (_ phoneNumber: String, _ fromNumber: String?) -> Void,
        openLiveAssist: @escaping (_ call: MobileCall) -> Void,
        onMissedCallCountChange: ((Int) -> Void)? = nil
    ) {
        self.bootstrap = bootstrap
        self.store = store
        self.api = api
        self.tokenProvider = tokenProvider
        self.showSettings = showSettings
        self.startCall = startCall
        self.startManualCall = startManualCall
        self.openLiveAssist = openLiveAssist
        self.onMissedCallCountChange = onMissedCallCountChange
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

    private var filteredRecents: [MobileCall] {
        let source: [MobileCall]
        switch selectedRecentsFilter {
        case .all:
            source = allCalls
        case .missed:
            source = allCalls.filter { $0.status.lowercased().contains("missed") }
        }

        guard !searchText.isEmpty else { return source }
        let query = searchText.lowercased()
        return source.filter { call in
            [
                call.contactName.lowercased(),
                call.contactPhone?.lowercased(),
                call.toNumber?.lowercased(),
                call.fromNumber?.lowercased(),
                call.summary?.lowercased(),
                call.transcript?.lowercased(),
            ]
            .compactMap { $0 }
            .contains(where: { $0.contains(query) })
        }
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
        return surfaces
    }

    private var voicemailCalls: [MobileCall] {
        let candidates = voicemailSource

        guard !searchText.isEmpty else { return candidates }
        let query = searchText.lowercased()
        return candidates.filter { call in
            [
                call.contactName.lowercased(),
                call.contactPhone?.lowercased(),
                call.summary?.lowercased(),
                call.transcript?.lowercased(),
            ]
            .compactMap { $0 }
            .contains(where: { $0.contains(query) })
        }
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
            ZStack(alignment: .bottomTrailing) {
                RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() })
                surfaceContent

                if selectedSurface != .keypad {
                    RotaryFloatingActionButton(
                        systemName: "circle.grid.3x3.fill",
                        tint: RotaryTheme.callAccent
                    ) {
                        RotaryHaptics.softTap()
                        selectedSurface = .keypad
                    }
                    .accessibilityLabel("Keypad")
                    .accessibilityIdentifier("rotary.callsKeypadButton")
                    .padding(.trailing, 18)
                    .padding(.bottom, 108)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                surfaceToolbar
            }
        }
        .sheet(isPresented: $showingCreateContact) {
            CallsCreateContactSheet(
                initialName: nil,
                initialPhoneNumber: selectedSurface == .keypad ? dialNumber.nonEmptyTrimmed : nil,
                api: api,
                tokenProvider: tokenProvider
            )
        }
        .task {
            onMissedCallCountChange?(store.missedCallCount)
            await store.refreshCallSurfaces()
        }
        .onChange(of: store.missedCallCount) { _, count in
            onMissedCallCountChange?(count)
        }
        .onChange(of: selectedSurface) { _, surface in
            searchText = ""
            isSearchVisible = false
            guard surface == .voicemail, !store.hasLoadedVoicemail else { return }
            Task { await store.loadVoicemails(forceRefresh: false) }
        }
        .onChange(of: store.voicemails.count) { _, count in
            guard count == 0, selectedSurface == .voicemail else { return }
            selectedSurface = .recents
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
            case .keypad:
                keypadSurface
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
        Color.clear
            .frame(width: 1, height: 1)
    }

    @ViewBuilder
    private var toolbarTrailing: some View {
        switch selectedSurface {
        case .contacts, .keypad:
            CallsToolbarIconButton(systemName: "plus") {
                showingCreateContact = true
            }
        case .recents, .voicemail:
            CallsToolbarIconButton(systemName: isSearchVisible ? "xmark" : "magnifyingglass") {
                RotaryHaptics.selection()
                if isSearchVisible {
                    searchText = ""
                }
                isSearchVisible.toggle()
            }
        }
    }

    private func refreshCurrentSurface(forceRefresh: Bool) async {
        switch selectedSurface {
        case .keypad:
            await store.refreshCallSurfaces(forceRefresh: forceRefresh)
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
        case .keypad:
            EmptyView()
        }
    }

    private var recentSurface: some View {
        VStack(spacing: 0) {
            callsSurfaceHeader(
                subtitle: store.missedCallCount > 0 ? "\(store.missedCallCount) missed" : "Recent activity"
            )

            CallsRecentsFilterControl(selection: $selectedRecentsFilter)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            if isSearchVisible {
                RotarySearchField(text: $searchText, prompt: searchPrompt)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

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
            callsSurfaceHeader(
                subtitle: voicemailCalls.isEmpty ? "Summaries, transcripts, and recordings" : "\(voicemailCalls.count) item\(voicemailCalls.count == 1 ? "" : "s")"
            )

            if isSearchVisible {
                RotarySearchField(text: $searchText, prompt: searchPrompt)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            voicemailList
        }
    }

    private var recentCallsList: some View {
        callsList(
            filteredRecents,
            emptyTitle: "No calls yet",
            emptyMessage: "Recent calls will show up here.",
            includeAssist: true,
            isLoading: store.isLoadingCalls,
            loadErrorText: store.loadError
        )
    }

    private var voicemailList: some View {
        Group {
            if RotaryDebugFlags.forceSkeletonPlaceholders || (store.isLoadingVoicemail && voicemailCalls.isEmpty) {
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
                List(voicemailCalls) { call in
                    HStack(spacing: 12) {
                        NavigationLink {
                            CallDetailScreen(
                                call: call,
                                allCalls: allCalls,
                                preferredSourceLine: manualDialSourceLine,
                                startManualCall: startManualCall,
                                api: api,
                                tokenProvider: tokenProvider
                            )
                        } label: {
                            VoicemailRow(call: call)
                        }
                        .buttonStyle(.plain)

                        if let callbackNumber = normalizedPhone(call.contactPhone ?? call.toNumber ?? call.fromNumber) {
                            Button {
                                RotaryHaptics.softTap()
                                startManualCall(callbackNumber, manualDialSourceLine)
                            } label: {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(RotaryTheme.accent)
                                    .frame(width: 34, height: 34)
                                    .background(CallsPhonePalette.keyFill, in: Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(CallsPhonePalette.chromeBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(RotaryTheme.elevatedStroke)
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.interactively)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func callsList(
        _ calls: [MobileCall],
        emptyTitle: String,
        emptyMessage: String,
        includeAssist: Bool,
        isLoading: Bool,
        loadErrorText: String?
    ) -> some View {
        Group {
            if RotaryDebugFlags.forceSkeletonPlaceholders || (isLoading && calls.isEmpty) {
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
                List(calls) { call in
                    NavigationLink {
                        CallDetailScreen(
                            call: call,
                            allCalls: allCalls,
                            preferredSourceLine: manualDialSourceLine,
                            startManualCall: startManualCall,
                            api: api,
                            tokenProvider: tokenProvider
                        )
                    } label: {
                        CompactCallRow(call: call)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if includeAssist {
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
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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
            CallsContactAvatar(title: ownerCardName, size: 38, accent: .yellow.opacity(0.35))

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
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text(dialNumber.isEmpty ? " " : dialNumber)
                        .font(.system(size: 38, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)

                    ZStack(alignment: .top) {
                        if let primaryKeypadSuggestion {
                            keypadSuggestionCard(primaryKeypadSuggestion)
                                .padding(.horizontal, 18)
                        }
                    }
                    .frame(height: 82, alignment: .top)
                }

                Spacer(minLength: 0)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                    ForEach(keypadDigits) { digit in
                        RotaryDialpadDigitButton(digit: digit) {
                            RotaryHaptics.lightTap()
                            dialNumber.append(digit.primary)
                        }
                    }
                }
                .frame(maxWidth: 320)
                .padding(.horizontal, 24)

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
                                    .frame(width: 72, height: 72)
                                    .glassEffect(.regular.tint(RotaryTheme.callAccent.opacity(0.4)).interactive(), in: .circle)
                            } else {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 72, height: 72)
                                    .background(RotaryTheme.callAccent, in: Circle())
                            }
                        }
                    }
                    .buttonStyle(RotaryPressScaleButtonStyle(pressedScale: 0.92))
                    .disabled(dialNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(dialNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)

                    if !dialNumber.isEmpty {
                        HStack {
                            Spacer()
                            RotaryRepeatDeleteButton(text: $dialNumber)
                        }
                        .frame(maxWidth: 320)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 36)
            }
            .offset(y: -56)

            Spacer(minLength: 0)
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
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)

            if remainingKeypadSuggestionCount > 0 {
                Divider()
                    .padding(.leading, 54)

                NavigationLink {
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 320)
        .background(CallsPhonePalette.chromeFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CallsPhonePalette.chromeBorder, lineWidth: 1)
        )
    }

    private var searchPrompt: String {
        switch selectedSurface {
        case .contacts:
            return "Search contacts"
        case .voicemail:
            return "Search voicemail"
        case .recents:
            return "Search calls"
        case .keypad:
            return ""
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

    private func callsSurfaceHeader(subtitle: String) -> some View {
        RotaryInlineStatusHeader(subtitle: subtitle)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
    }
}

private struct RotaryDialpadDigitButton: View {
    let digit: KeypadDigit
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(digit.displayPrimary)
                    .font(.system(size: digit.usesCompactPrimaryFont ? 31 : 37, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(height: 38, alignment: .bottom)

                Text(digit.secondary)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                    .frame(height: 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 82)
            .modifier(RotaryDialpadSurfaceModifier())
        }
        .buttonStyle(RotaryPressScaleButtonStyle(pressedScale: 0.92))
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
        RotaryGlassIcon(systemName: systemName, size: 16, frameSize: 36)
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
        HStack(spacing: 8) {
            ForEach(CallsRecentsFilter.allCases) { filter in
                Button {
                    RotaryHaptics.selection()
                    selection = filter
                } label: {
                    RotaryPill(text: filter.rawValue, active: selection == filter)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        HStack(spacing: 12) {
            CallsContactAvatar(title: call.contactName, size: 38)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(primaryTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isMissedCall ? RotaryTheme.destructive : Color.primary)
                        .lineLimit(1)

                    if isUnreadVoicemail {
                        Circle()
                            .fill(RotaryTheme.accent)
                            .frame(width: 7, height: 7)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: directionIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isMissedCall ? RotaryTheme.destructive : .secondary)

                    Text(locationAndWhenText)
                        .font(.subheadline)
                        .foregroundStyle(isMissedCall ? RotaryTheme.destructive.opacity(0.85) : .secondary)
                        .lineLimit(1)
                }

                if let previewText {
                    Text(previewText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 8)
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

    private var locationAndWhenText: String {
        let location = callLocationLabel(for: call) ?? fallbackNumber
        let when = rotaryCallTimestampLabel(call.createdAt)
        guard !when.isEmpty else { return location }
        return "\(location) • \(when)"
    }

    private var previewText: String? {
        call.summary?.nonEmptyTrimmed ?? call.transcript?.nonEmptyTrimmed
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
        HStack(alignment: .top, spacing: 12) {
            CallsContactAvatar(title: call.contactName, size: 38)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(primaryTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)

                    if isUnreadVoicemail {
                        Circle()
                            .fill(RotaryTheme.accent)
                            .frame(width: 7, height: 7)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isMissedCall ? RotaryTheme.destructive : .secondary)

                    Text(locationAndWhenText)
                        .font(.subheadline)
                        .foregroundStyle(isMissedCall ? RotaryTheme.destructive.opacity(0.85) : .secondary)
                        .lineLimit(1)
                }

                if let previewLine {
                    Text(previewLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 8)
    }

    private var primaryTitle: String {
        let trimmed = call.contactName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallbackNumber : trimmed
    }

    private var previewLine: String? {
        if let transcript = call.transcript?.nonEmptyTrimmed {
            return "\"\(transcript)\""
        }
        if let summary = call.summary?.nonEmptyTrimmed {
            return summary
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

    private var locationAndWhenText: String {
        let location = callLocationLabel(for: call) ?? fallbackNumber
        let when = rotaryCallTimestampLabel(call.createdAt)
        guard !when.isEmpty else { return location }
        return "\(location) • \(when)"
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
    callIsVoicemailLike(call) && call.readAt == nil
}

private func callIsVoicemailLike(_ call: MobileCall) -> Bool {
    guard let recordingURL = call.recordingUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
          !recordingURL.isEmpty
    else {
        return false
    }
    return URL(string: recordingURL) != nil
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
    @State private var didAutoRepeat = false

    var body: some View {
        Button {
            deleteOnce()
        } label: {
            Image(systemName: "delete.left.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(text.isEmpty ? 0.18 : 0.82))
                .frame(width: 46, height: 32)
                .background(CallsPhonePalette.chromeFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(CallsPhonePalette.chromeBorder, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onLongPressGesture(
            minimumDuration: 0.35,
            maximumDistance: 36,
            pressing: { isPressing in
                if !isPressing {
                    cancelRepeat()
                }
            },
            perform: beginRepeatingDeletion
        )
        .onDisappear {
            cancelRepeat()
        }
    }

    private func deleteOnce() {
        guard !didAutoRepeat, !text.isEmpty else {
            didAutoRepeat = false
            return
        }
        RotaryHaptics.selection()
        text.removeLast()
    }

    private func beginRepeatingDeletion() {
        guard repeatTask == nil, !text.isEmpty else { return }
        repeatTask = Task { @MainActor in
            didAutoRepeat = true
            var intervalMilliseconds = 110
            while !Task.isCancelled && !text.isEmpty {
                RotaryHaptics.selection()
                text.removeLast()
                try? await Task.sleep(for: .milliseconds(intervalMilliseconds))
                intervalMilliseconds = max(34, intervalMilliseconds - 12)
            }
        }
    }

    private func cancelRepeat() {
        repeatTask?.cancel()
        repeatTask = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(30))
            didAutoRepeat = false
        }
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
            if !nameSuggestions.isEmpty {
                Section("Names") {
                    ForEach(nameSuggestions) { suggestion in
                        suggestionRow(suggestion)
                    }
                }
            }

            if !numberSuggestions.isEmpty {
                Section("Numbers") {
                    ForEach(numberSuggestions) { suggestion in
                        suggestionRow(suggestion)
                    }
                }
            }
        }
        .navigationTitle(selectedNumber)
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

struct CallDetailScreen: View {
    let call: MobileCall
    let allCalls: [MobileCall]
    let preferredSourceLine: String?
    let startManualCall: (_ phoneNumber: String, _ fromNumber: String?) -> Void
    let api: RotaryAPIClient
    let tokenProvider: RotaryTokenProvider

    @State private var player = RotaryAudioPlayer()
    @State private var callDetailPayload: MobileCallDetailPayload?
    @State private var voicemailDetailPayload: MobileVoicemailDetailPayload?
    @State private var loadError: String?
    @State private var showingCreateContact = false

    private var primaryNumber: String? {
        normalizedPhone(displayCall.contactPhone ?? displayCall.toNumber ?? displayCall.fromNumber)
    }

    private var relatedCalls: [MobileCall] {
        if let relatedCalls = callDetailPayload?.relatedCalls, !relatedCalls.isEmpty {
            return relatedCalls
        }
        if let relatedCalls = voicemailDetailPayload?.relatedCalls, !relatedCalls.isEmpty {
            return relatedCalls
        }
        guard let primaryNumber else { return [] }
        return allCalls.filter {
            normalizedPhone($0.contactPhone ?? $0.toNumber ?? $0.fromNumber) == primaryNumber
        }
    }

    private var displayCall: MobileCall {
        voicemailDetailPayload?.voicemail ?? callDetailPayload?.call ?? call
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                RotaryGlassCard {
                    Text(displayCall.contactName)
                        .font(.title2.weight(.bold))
                    if let primaryNumber {
                        Text(primaryNumber)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        guard let primaryNumber else { return }
                        RotaryHaptics.softTap()
                        startManualCall(primaryNumber, preferredSourceLine)
                    } label: {
                        Label("Call Back", systemImage: "phone.fill")
                    }
                    .buttonStyle(RotaryPrimaryButtonStyle())
                    .disabled(primaryNumber == nil)
                }

                RotaryGlassCard {
                    Text("Details")
                        .font(.headline)
                    LabeledContent("Direction", value: directionTitle)
                    if let date = parseDate(displayCall.createdAt) {
                        LabeledContent("When", value: date.formatted(.dateTime.month().day().hour().minute()))
                    }
                    if let durationText {
                        LabeledContent("Duration", value: durationText)
                    }
                    LabeledContent("Status", value: statusLabel(for: displayCall))
                    if let screening = displayCall.screeningOutcome, !screening.isEmpty {
                        LabeledContent("Screening", value: screening.replacingOccurrences(of: "_", with: " ").capitalized)
                    }
                }

                if let url = playableVoicemailURL {
                    RotaryGlassCard {
                        Text("Voicemail")
                            .font(.headline)
                        VoicemailPlaybackCard(player: player, url: url)
                    }
                }

                if let summary = displayCall.summary, !summary.isEmpty {
                    RotaryGlassCard {
                        Text("Summary")
                            .font(.headline)
                        Text(summary)
                            .foregroundStyle(.secondary)
                    }
                }

                if let transcript = displayCall.transcript, !transcript.isEmpty {
                    RotaryGlassCard {
                        Text("Transcript")
                            .font(.headline)
                        Text(transcript)
                            .foregroundStyle(.secondary)
                    }
                }

                if let loadError, !loadError.isEmpty {
                    RotaryGlassCard {
                        Text(loadError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if relatedCalls.count > 1 {
                    RotaryGlassCard {
                        Text("History")
                            .font(.headline)
                        ForEach(relatedCalls.prefix(12)) { relatedCall in
                            Divider()
                            CompactCallRow(call: relatedCall)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(RotaryBackdrop())
        .navigationTitle("Call")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if primaryNumber != nil {
                    Button {
                        showingCreateContact = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateContact) {
            CallsCreateContactSheet(
                initialName: displayCall.contactName == "Unknown caller" ? nil : displayCall.contactName,
                initialPhoneNumber: primaryNumber,
                api: api,
                tokenProvider: tokenProvider
            )
        }
        .task {
            await loadDetails()
        }
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

    private var playableVoicemailURL: URL? {
        guard let recordingURL = displayCall.recordingUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !recordingURL.isEmpty
        else {
            return nil
        }
        return URL(string: recordingURL)
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
            if playableVoicemailURL != nil {
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

private struct VoicemailPlaybackCard: View {
    @Bindable var player: RotaryAudioPlayer
    let url: URL

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
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(timerText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ),
                in: 0 ... max(player.duration, 1)
            )
            .tint(RotaryTheme.accent)
        }
        .task {
            player.load(url: url)
        }
    }

    private var timerText: String {
        let current = Int(player.currentTime.rounded())
        let total = Int(player.duration.rounded())
        return "\(formatDuration(current)) / \(formatDuration(total))"
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
