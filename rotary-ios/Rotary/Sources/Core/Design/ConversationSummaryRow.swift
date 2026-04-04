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
        HStack(spacing: 12) {
            RotaryAvatarView(title: title, size: avatarSize, imageURL: avatarURL)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.body.weight(isUnread ? .semibold : .regular))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if !timestamp.isEmpty {
                        Text(timestamp)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    if isUnread {
                        Circle()
                            .fill(RotaryTheme.accent)
                            .frame(width: 10, height: 10)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }
}
