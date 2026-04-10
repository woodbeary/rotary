import SwiftUI

enum RotaryConversationDirection: String, Hashable {
    case inbound
    case outbound
}

enum RotaryMessageDeliveryReceipt: String, Hashable {
    case sent
    case delivered
    case read
    case undelivered

    var label: String {
        switch self {
        case .sent:
            return "Sent"
        case .delivered:
            return "Delivered"
        case .read:
            return "Read"
        case .undelivered:
            return "Undelivered"
        }
    }
}

struct RotaryConversationAttachmentPreview: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let kind: String
}

struct RotaryConversationBubbleModel: Identifiable, Hashable {
    let id: String
    let direction: RotaryConversationDirection
    let text: String
    let originalText: String?
    let sourceLanguage: String?
    let targetLanguage: String?
    let timestamp: String
    let date: Date?
    let statusText: String?
    let deliveryReceipt: RotaryMessageDeliveryReceipt?
    let statusSystemImage: String?
    let wasTranslated: Bool
    let attachments: [RotaryConversationAttachmentPreview]
    let isPreviewPlaceholder: Bool

    init(
        id: String,
        direction: RotaryConversationDirection,
        text: String,
        originalText: String? = nil,
        sourceLanguage: String? = nil,
        targetLanguage: String? = nil,
        timestamp: String,
        date: Date?,
        statusText: String? = nil,
        deliveryReceipt: RotaryMessageDeliveryReceipt? = nil,
        statusSystemImage: String? = nil,
        wasTranslated: Bool = false,
        attachments: [RotaryConversationAttachmentPreview] = [],
        isPreviewPlaceholder: Bool = false
    ) {
        self.id = id
        self.direction = direction
        self.text = text
        self.originalText = originalText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
        self.date = date
        self.statusText = statusText
        self.deliveryReceipt = deliveryReceipt
        self.statusSystemImage = statusSystemImage
        self.wasTranslated = wasTranslated
        self.attachments = attachments
        self.isPreviewPlaceholder = isPreviewPlaceholder
    }
}

private enum RotaryConversationRow: Hashable, Identifiable {
    case day(String, String)
    case message(RotaryConversationBubbleModel)

    var id: String {
        switch self {
        case let .day(id, _):
            return id
        case let .message(message):
            return message.id
        }
    }
}

struct RotaryConversationTranscriptView: View {
    let messages: [RotaryConversationBubbleModel]
    var selectionMode = false
    var selectedMessageIDs: Set<String> = []
    var onToggleMessageSelection: ((RotaryConversationBubbleModel) -> Void)?
    var onCopyMessage: ((RotaryConversationBubbleModel) -> Void)?
    var onTranslateMessage: ((RotaryConversationBubbleModel) -> Void)?
    var onSelectComposer: (() -> Void)?
    var onMoreMessage: ((RotaryConversationBubbleModel) -> Void)?
    var tapbackByMessageID: [String: String] = [:]
    var onSetTapback: ((RotaryConversationBubbleModel, String?) -> Void)?
    @GestureState private var revealsTimestamps = false

    private var rows: [RotaryConversationRow] {
        var results: [RotaryConversationRow] = []
        var lastDayKey: String?

        for message in messages {
            let key = message.date.map(RotaryDateFormatting.dayKey(for:))
            if let key, key != lastDayKey {
                results.append(.day("day-\(key)", RotaryDateFormatting.dayDividerLabel(for: message.date)))
                lastDayKey = key
            }
            results.append(.message(message))
        }

        return results
    }

    var body: some View {
        LazyVStack(spacing: 14) {
            ForEach(rows) { row in
                switch row {
                case let .day(_, label):
                    HStack {
                        Spacer(minLength: 0)
                        Text(label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RotaryTheme.softSurface.opacity(0.9),
                                in: Capsule(style: .continuous)
                            )
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 2)
                case let .message(message):
                    RotaryConversationBubble(
                        message: message,
                        selectionMode: selectionMode,
                        isSelected: selectedMessageIDs.contains(message.id),
                        onToggleSelection: onToggleMessageSelection,
                        onCopyMessage: onCopyMessage,
                        onTranslateMessage: onTranslateMessage,
                        onSelectComposer: onSelectComposer,
                        onMoreMessage: onMoreMessage,
                        selectedTapback: tapbackByMessageID[message.id],
                        onSetTapback: onSetTapback,
                        revealsTimestamp: revealsTimestamps
                    )
                }
            }
        }
        .simultaneousGesture(revealTimestampGesture)
    }

    private var revealTimestampGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($revealsTimestamps) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width < -18
            }
    }
}

private struct RotaryConversationBubble: View {
    let message: RotaryConversationBubbleModel
    var selectionMode = false
    var isSelected = false
    var onToggleSelection: ((RotaryConversationBubbleModel) -> Void)?
    var onCopyMessage: ((RotaryConversationBubbleModel) -> Void)?
    var onTranslateMessage: ((RotaryConversationBubbleModel) -> Void)?
    var onSelectComposer: (() -> Void)?
    var onMoreMessage: ((RotaryConversationBubbleModel) -> Void)?
    var selectedTapback: String?
    var onSetTapback: ((RotaryConversationBubbleModel, String?) -> Void)?
    var revealsTimestamp = false
    @State private var showingOriginalText = false
    @State private var showingQuickActions = false

    private var isOutgoing: Bool {
        message.direction == .outbound
    }

    private var originalText: String? {
        guard let original = message.originalText else {
            return nil
        }
        let candidate = rotarySanitizedConversationText(original)
        guard !candidate.isEmpty,
              candidate != renderedMessageText else {
            return nil
        }
        return candidate
    }

    private var renderedMessageText: String {
        rotarySanitizedConversationText(message.text)
    }

    private var supportsContextMenu: Bool {
        !selectionMode
            && (onCopyMessage != nil
                || onTranslateMessage != nil
                || onSelectComposer != nil
                || onMoreMessage != nil
                || onSetTapback != nil)
    }

    private var statusLabel: String? {
        if let deliveryReceipt = message.deliveryReceipt {
            return deliveryReceipt.label
        }
        if let statusText = message.statusText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !statusText.isEmpty {
            return statusText
        }
        return nil
    }

    private var hasProviderStatusIcon: Bool {
        guard let symbol = message.statusSystemImage?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !symbol.isEmpty
    }

    private var showsOutgoingFooter: Bool {
        guard isOutgoing else { return false }
        return (revealsTimestamp && !message.timestamp.isEmpty)
            || hasProviderStatusIcon
            || message.wasTranslated
            || statusLabel != nil
    }

    private var showsIncomingFooter: Bool {
        !isOutgoing && revealsTimestamp && !message.timestamp.isEmpty
    }

    private var showsExternalFooter: Bool {
        showsOutgoingFooter || showsIncomingFooter
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isOutgoing {
                Spacer(minLength: 52)
            }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                bubbleCard

                if showsExternalFooter {
                    metadataFooter
                }
            }

            if !isOutgoing {
                Spacer(minLength: 52)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if showingQuickActions {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.90)) {
                    showingQuickActions = false
                }
                return
            }
            if selectionMode {
                onToggleSelection?(message)
            }
        }
        .onLongPressGesture {
            guard supportsContextMenu else { return }
            RotaryKeyboard.dismiss()
            RotaryHaptics.softTap()
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                showingQuickActions = true
            }
        }
        .overlay(alignment: isOutgoing ? .topTrailing : .topLeading) {
            if showingQuickActions {
                RotaryMessageQuickActionsMenu(
                    selectedTapback: selectedTapback,
                    onSelectTapback: { emoji in
                        if selectedTapback == emoji {
                            onSetTapback?(message, nil)
                        } else {
                            onSetTapback?(message, emoji)
                        }
                    },
                    onCopy: { onCopyMessage?(message) },
                    onTranslate: { onTranslateMessage?(message) },
                    onSelectComposer: onSelectComposer,
                    onMore: { onMoreMessage?(message) },
                    onDismiss: {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.94)) {
                            showingQuickActions = false
                        }
                    }
                )
                .offset(x: isOutgoing ? -6 : 6, y: 8)
                .transition(.scale(scale: 0.94, anchor: isOutgoing ? .topTrailing : .topLeading).combined(with: .opacity))
                .zIndex(5)
            }
        }
        .zIndex(showingQuickActions ? 5 : 0)
    }

    private var bubbleCard: some View {
        messageContent
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: min(UIScreen.main.bounds.width * 0.76, 324), alignment: .leading)
            .background(
                isOutgoing ? RotaryTheme.outgoingBubble : RotaryTheme.incomingBubble,
                in: bubbleShape
            )
            .overlay(
                bubbleShape
                    .stroke(isOutgoing ? Color.clear : RotaryTheme.elevatedStroke, lineWidth: 1)
            )
            .opacity(message.isPreviewPlaceholder ? 0.88 : 1)
            .overlay(alignment: isOutgoing ? .topTrailing : .topLeading) {
                if selectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? RotaryTheme.accent : Color.secondary)
                        .padding(6)
                }
            }
    }

    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if message.isPreviewPlaceholder {
                Text("Recent preview")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isOutgoing ? Color.white.opacity(0.78) : .secondary)
            }

            if !renderedMessageText.isEmpty {
                Text(renderedMessageText)
                    .font(.body)
                    .lineSpacing(1.2)
                    .foregroundStyle(isOutgoing ? Color.white : Color.primary)
            }

            if let originalText {
                Button {
                    showingOriginalText.toggle()
                } label: {
                    Text(showingOriginalText ? "Hide original" : "View original")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isOutgoing ? Color.white.opacity(0.86) : RotaryTheme.accent)
                }
                .buttonStyle(.plain)

                if showingOriginalText {
                    Text(originalText)
                        .font(.callout)
                        .lineSpacing(1.15)
                        .foregroundStyle(isOutgoing ? Color.white.opacity(0.9) : .secondary)
                }
            }

            if !message.attachments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(message.attachments) { attachment in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isOutgoing ? Color.white.opacity(0.16) : RotaryTheme.softSurface)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: symbol(for: attachment.kind))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(isOutgoing ? Color.white : RotaryTheme.accent)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(attachment.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(isOutgoing ? Color.white : Color.primary)
                                    .lineLimit(2)

                                Text(attachment.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(isOutgoing ? Color.white.opacity(0.76) : .secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(10)
                        .background(
                            isOutgoing ? Color.white.opacity(0.14) : RotaryTheme.nestedBubble,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                }
            }

            if let selectedTapback {
                HStack(spacing: 0) {
                    Text(selectedTapback)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RotaryTheme.secondarySurface.opacity(0.95),
                            in: Capsule(style: .continuous)
                        )
                }
                .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
            }
        }
    }

    private var metadataFooter: some View {
        HStack(spacing: 6) {
            if revealsTimestamp, !message.timestamp.isEmpty {
                Text(message.timestamp)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if isOutgoing {
                if let statusSystemImage = message.statusSystemImage, !statusSystemImage.isEmpty {
                    Image(systemName: statusSystemImage)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                if message.wasTranslated {
                    if let onTranslateMessage {
                        Button {
                            RotaryHaptics.selection()
                            onTranslateMessage(message)
                        } label: {
                            Image(systemName: "globe")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Translated message")
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if let statusLabel {
                    Text(statusLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(
            maxWidth: min(UIScreen.main.bounds.width * 0.76, 324),
            alignment: isOutgoing ? .trailing : .leading
        )
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 24,
            bottomLeadingRadius: isOutgoing ? 24 : 9,
            bottomTrailingRadius: isOutgoing ? 9 : 24,
            topTrailingRadius: 24,
            style: .continuous
        )
    }

    private func symbol(for kind: String) -> String {
        switch kind.lowercased() {
        case "image", "photo":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "audio":
            return "waveform"
        case "link":
            return "link"
        case "location":
            return "mappin"
        default:
            return "doc"
        }
    }
}

private struct RotaryMessageQuickActionsMenu: View {
    let selectedTapback: String?
    let onSelectTapback: (String) -> Void
    let onCopy: (() -> Void)?
    let onTranslate: (() -> Void)?
    let onSelectComposer: (() -> Void)?
    let onMore: (() -> Void)?
    let onDismiss: (() -> Void)?

    private let tapbackOptions = ["👍", "❤️", "😂", "‼️", "❓"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            tapbackRow

            VStack(alignment: .leading, spacing: 6) {
                actionButton("Copy", systemName: "doc.on.doc", action: onCopy)
                actionButton("Translate", systemName: "globe", action: onTranslate)
                actionButton("Select", systemName: "selection.pin.in.out", action: onSelectComposer)
                actionButton("More", systemName: "ellipsis.circle", action: onMore)
            }
        }
        .padding(10)
        .frame(width: 214)
        .background(menuBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: RotaryTheme.shadow.opacity(0.16), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private var tapbackRow: some View {
        HStack(spacing: 8) {
            ForEach(tapbackOptions, id: \.self) { emoji in
                Button {
                    RotaryHaptics.selection()
                    onSelectTapback(emoji)
                    onDismiss?()
                } label: {
                    Text(emoji)
                        .font(.headline)
                        .frame(width: 34, height: 34)
                        .modifier(RotaryTapbackGlyphBackground(isSelected: selectedTapback == emoji))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var menuBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(.white.opacity(0.16)).interactive(), in: .rect(cornerRadius: 20))
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RotaryTheme.secondarySurface)
        }
    }

    @ViewBuilder
    private func actionButton(_ title: String, systemName: String, action: (() -> Void)?) -> some View {
        if let action {
            Button {
                RotaryHaptics.selection()
                action()
                onDismiss?()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: systemName)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 18)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .modifier(RotaryQuickActionButtonBackground())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct RotaryQuickActionButtonBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.tint(.white.opacity(0.14)).interactive(), in: .rect(cornerRadius: 12))
        } else {
            content
                .background(RotaryTheme.softSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct RotaryTapbackGlyphBackground: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(
                    .regular
                        .tint(.white.opacity(isSelected ? 0.24 : 0.14))
                        .interactive(),
                    in: .circle
                )
        } else {
            content
                .background(
                    (isSelected ? RotaryTheme.softSurface : Color.clear),
                    in: Circle()
                )
        }
    }
}
