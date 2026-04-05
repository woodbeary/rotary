import SwiftUI

struct RotaryConversationSummaryRow: View {
    let title: String
    let preview: String
    let timestamp: String
    let avatarURL: String?
    let avatarSize: CGFloat
    let isUnread: Bool
    let showsPreviewSkeleton: Bool
    let previewSystemImage: String?

    init(
        title: String,
        preview: String,
        timestamp: String,
        avatarURL: String? = nil,
        avatarSize: CGFloat = 50,
        isUnread: Bool = false,
        showsPreviewSkeleton: Bool = false,
        previewSystemImage: String? = nil
    ) {
        self.title = title
        self.preview = preview
        self.timestamp = timestamp
        self.avatarURL = avatarURL
        self.avatarSize = avatarSize
        self.isUnread = isUnread
        self.showsPreviewSkeleton = showsPreviewSkeleton
        self.previewSystemImage = previewSystemImage
    }

    var body: some View {
        let trimmedPreview = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasPreview = !trimmedPreview.isEmpty
        let showsSecondaryRow = hasPreview || showsPreviewSkeleton

        HStack(alignment: showsSecondaryRow ? .top : .center, spacing: 14) {
            RotaryAvatarView(title: title, size: avatarSize, imageURL: avatarURL)

            VStack(alignment: .leading, spacing: hasPreview ? 6 : 0) {
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
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if let previewSystemImage {
                            Image(systemName: previewSystemImage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Text(trimmedPreview)
                            .font(.subheadline.weight(isUnread ? .medium : .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                } else if showsPreviewSkeleton {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(RotaryTheme.softSurface)
                        .frame(width: min(max(CGFloat(title.count) * 6.8, 88), 148), height: 11)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(RotaryTheme.elevatedStroke.opacity(0.55), lineWidth: 0.8)
                        )
                        .redacted(reason: .placeholder)
                }
            }
            .frame(maxWidth: .infinity, minHeight: showsSecondaryRow ? nil : avatarSize, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, showsSecondaryRow ? 10 : 6)
    }
}
