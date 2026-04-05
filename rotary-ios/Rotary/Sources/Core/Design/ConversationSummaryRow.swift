import SwiftUI

struct RotaryConversationSummaryRow: View {
    let title: String
    let preview: String
    let timestamp: String
    let avatarURL: String?
    let avatarSize: CGFloat
    let isUnread: Bool

    init(
        title: String,
        preview: String,
        timestamp: String,
        avatarURL: String? = nil,
        avatarSize: CGFloat = 50,
        isUnread: Bool = false
    ) {
        self.title = title
        self.preview = preview
        self.timestamp = timestamp
        self.avatarURL = avatarURL
        self.avatarSize = avatarSize
        self.isUnread = isUnread
    }

    var body: some View {
        let trimmedPreview = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasPreview = !trimmedPreview.isEmpty

        HStack(alignment: .top, spacing: 14) {
            RotaryAvatarView(title: title, size: avatarSize, imageURL: avatarURL)

            VStack(alignment: .leading, spacing: hasPreview ? 6 : 2) {
                HStack(alignment: .top, spacing: 8) {
                    Text(title)
                        .font(.body.weight(isUnread ? .semibold : .medium))
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    if !timestamp.isEmpty {
                        HStack(spacing: 6) {
                            Text(timestamp)
                                .font(.caption.weight(isUnread ? .semibold : .regular))
                                .foregroundStyle(isUnread ? RotaryTheme.accent : .secondary)

                            if isUnread {
                                Circle()
                                    .fill(RotaryTheme.accent)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }

                if hasPreview {
                    Text(trimmedPreview)
                        .font(.subheadline.weight(isUnread ? .medium : .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 10)
    }
}
