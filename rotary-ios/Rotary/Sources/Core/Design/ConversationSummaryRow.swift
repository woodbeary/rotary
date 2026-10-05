import SwiftUI

func rotarySanitizedConversationText(_ value: String) -> String {
    let normalizedLineEndings = value.replacingOccurrences(of: "\r\n", with: "\n")

    let withoutSignoff = normalizedLineEndings.replacingOccurrences(
        of: #"\s*\[signoff:[^\]]+\]"#,
        with: "",
        options: .regularExpression
    )

    let withoutHeadings = withoutSignoff.replacingOccurrences(
        of: #"(?m)^\s{0,3}#{1,6}\s*"#,
        with: "",
        options: .regularExpression
    )

    let withoutBullets = withoutHeadings.replacingOccurrences(
        of: #"(?m)^\s*[-*+]\s+"#,
        with: "",
        options: .regularExpression
    )

    let withoutInlineMarkers = withoutBullets
        .replacingOccurrences(of: "`", with: "")
        .replacingOccurrences(of: "**", with: "")
        .replacingOccurrences(of: "__", with: "")

    return withoutInlineMarkers
        .replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
        .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func rotarySanitizedConversationPreview(_ value: String) -> String {
    rotarySanitizedConversationText(value)
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

struct RotaryConversationSummaryRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let preview: String
    let timestamp: String
    let avatarURL: String?
    let avatarSize: CGFloat
    let isUnread: Bool
    let showsPreviewSkeleton: Bool
    let previewSystemImage: String?
    let showsChevron: Bool

    init(
        title: String,
        preview: String,
        timestamp: String,
        avatarURL: String? = nil,
        avatarSize: CGFloat = 50,
        isUnread: Bool = false,
        showsPreviewSkeleton: Bool = false,
        previewSystemImage: String? = nil,
        showsChevron: Bool = true
    ) {
        self.title = title
        self.preview = preview
        self.timestamp = timestamp
        self.avatarURL = avatarURL
        self.avatarSize = avatarSize
        self.isUnread = isUnread
        self.showsPreviewSkeleton = showsPreviewSkeleton
        self.previewSystemImage = previewSystemImage
        self.showsChevron = showsChevron
    }

    var body: some View {
        let trimmedPreview = rotarySanitizedConversationPreview(preview)
        let hasPreview = !trimmedPreview.isEmpty

        HStack(spacing: 12) {
            RotaryAvatarView(title: title, size: max(avatarSize - 6, 36), imageURL: avatarURL)

            VStack(alignment: .leading, spacing: hasPreview ? 4 : 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.system(size: 17, weight: isUnread ? .semibold : .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if !timestamp.isEmpty {
                        Text(timestamp)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 2)
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
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                } else if showsPreviewSkeleton {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(RotaryTheme.softSurface)
                        .frame(width: min(max(CGFloat(title.count) * 6.4, 88), 148), height: 11)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(RotaryTheme.elevatedStroke.opacity(0.55), lineWidth: 0.8)
                        )
                        .redacted(reason: .placeholder)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 11)
        }
        .padding(.horizontal, 12)
        .background(
            rowFill,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(rowStroke, lineWidth: 0.9)
        )
        .shadow(color: RotaryTheme.shadow.opacity(colorScheme == .dark ? 0.14 : 0.04), radius: 5, x: 0, y: 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var rowFill: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 0.80)
            }
            return UIColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 0.98)
        })
    }

    private var rowStroke: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor.separator.withAlphaComponent(0.24)
            }
            return UIColor.separator.withAlphaComponent(0.10)
        })
    }
}
