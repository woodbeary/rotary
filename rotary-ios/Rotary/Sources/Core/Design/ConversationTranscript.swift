import SwiftUI

enum RotaryConversationDirection: String, Hashable {
    case inbound
    case outbound
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
    let timestamp: String
    let date: Date?
    let statusText: String?
    let attachments: [RotaryConversationAttachmentPreview]
    let isPreviewPlaceholder: Bool

    init(
        id: String,
        direction: RotaryConversationDirection,
        text: String,
        timestamp: String,
        date: Date?,
        statusText: String? = nil,
        attachments: [RotaryConversationAttachmentPreview] = [],
        isPreviewPlaceholder: Bool = false
    ) {
        self.id = id
        self.direction = direction
        self.text = text
        self.timestamp = timestamp
        self.date = date
        self.statusText = statusText
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
                    RotaryConversationBubble(message: message)
                }
            }
        }
    }
}

private struct RotaryConversationBubble: View {
    let message: RotaryConversationBubbleModel

    private var isOutgoing: Bool {
        message.direction == .outbound
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isOutgoing {
                Spacer(minLength: 52)
            }

            VStack(alignment: .leading, spacing: 6) {
                if message.isPreviewPlaceholder {
                    Text("Recent preview")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isOutgoing ? Color.white.opacity(0.78) : .secondary)
                }

                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.body)
                        .lineSpacing(1.2)
                        .foregroundStyle(isOutgoing ? Color.white : Color.primary)
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

                HStack(spacing: 6) {
                    if !message.timestamp.isEmpty {
                        Text(message.timestamp)
                            .font(.caption2)
                            .foregroundStyle(isOutgoing ? Color.white.opacity(0.72) : .secondary)
                    }

                    if let statusText = message.statusText, !statusText.isEmpty {
                        Text(statusText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isOutgoing ? Color.white.opacity(0.72) : .secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: min(UIScreen.main.bounds.width * 0.76, 324), alignment: .leading)
            .background(
                isOutgoing ? RotaryTheme.accent : RotaryTheme.incomingBubble,
                in: bubbleShape
            )
            .overlay(
                bubbleShape
                    .stroke(isOutgoing ? Color.clear : RotaryTheme.elevatedStroke, lineWidth: 1)
            )
            .opacity(message.isPreviewPlaceholder ? 0.88 : 1)

            if !isOutgoing {
                Spacer(minLength: 52)
            }
        }
        .frame(maxWidth: .infinity)
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
