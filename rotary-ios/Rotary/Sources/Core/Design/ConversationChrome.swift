import SwiftUI

struct RotaryAvatarView: View {
    let title: String
    let size: CGFloat
    let tint: Color
    let imageURL: String?

    init(
        title: String,
        size: CGFloat = 34,
        tint: Color = RotaryTheme.avatarTint,
        imageURL: String? = nil
    ) {
        self.title = title
        self.size = size
        self.tint = tint
        self.imageURL = imageURL
    }

    var body: some View {
        Group {
            if let imageURL, let uiImage = RotaryAvatarImageResolver.image(from: imageURL) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(RotaryTheme.softSurface)
                        .overlay(
                            Circle()
                                .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
                        )

                    if shouldShowFallbackPersonIcon {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: size * 0.46, weight: .semibold))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(initials)
                            .font(.system(size: size * 0.40, weight: .semibold))
                    }
                }
                    .frame(width: size, height: size)
                    .shadow(color: RotaryTheme.shadow.opacity(0.08), radius: 4, x: 0, y: 2)
            }
        }
        .foregroundStyle(.primary)
    }

    private var shouldShowFallbackPersonIcon: Bool {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty || normalized.contains("nullvoice") || initials == "?"
    }

    private var initials: String {
        let words = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
        let letters = words.prefix(2).compactMap { word -> String? in
            guard let character = word.first(where: { $0.isLetter }) else { return nil }
            return String(character)
        }
        .joined()

        if !letters.isEmpty {
            return letters.uppercased()
        }

        let fallback = String(
            title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .filter { $0.isLetter || $0.isNumber }
                .prefix(2)
        )
        return fallback.isEmpty ? "?" : fallback.uppercased()
    }
}

private enum RotaryAvatarImageResolver {
    static func image(from value: String) -> UIImage? {
        imageFromDataURL(value)
    }

    private static func imageFromDataURL(_ value: String) -> UIImage? {
        guard value.lowercased().hasPrefix("data:image"),
              let commaIndex = value.firstIndex(of: ",")
        else {
            return nil
        }

        let payload = String(value[value.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: payload) else { return nil }
        return UIImage(data: data)
    }
}

struct RotaryConversationTopHeader: View {
    let title: String
    let subtitle: String?
    let avatarSize: CGFloat
    let imageURL: String?
    let action: (() -> Void)?

    init(
        title: String,
        subtitle: String? = nil,
        avatarSize: CGFloat = 48,
        imageURL: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.avatarSize = avatarSize
        self.imageURL = imageURL
        self.action = action
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var content: some View {
        VStack(spacing: 5) {
            RotaryAvatarView(title: title, size: avatarSize, imageURL: imageURL)

            VStack(spacing: subtitle?.isEmpty == false ? 2 : 0) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(titlePillBackground)
            .overlay(titlePillStroke)
        }
        .frame(maxWidth: 220)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .shadow(color: RotaryTheme.shadow.opacity(0.08), radius: 10, x: 0, y: 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var titlePillBackground: some View {
        if #available(iOS 26, *) {
            Capsule(style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(.white.opacity(0.14)).interactive(action != nil), in: .capsule)
        } else {
            Capsule(style: .continuous)
                .fill(RotaryTheme.chromeFill)
        }
    }

    private var titlePillStroke: some View {
        Capsule(style: .continuous)
            .stroke(RotaryTheme.chromeStroke.opacity(0.85), lineWidth: 1)
    }
}

struct RotaryConversationThreadHeader: View {
    let title: String
    let subtitle: String?
    let avatarSize: CGFloat
    let imageURL: String?
    let participantTitles: [String]
    let participantImageURLs: [String]
    let action: (() -> Void)?

    init(
        title: String,
        subtitle: String? = nil,
        avatarSize: CGFloat = 56,
        imageURL: String? = nil,
        participantTitles: [String] = [],
        participantImageURLs: [String] = [],
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.avatarSize = avatarSize
        self.imageURL = imageURL
        self.participantTitles = participantTitles
        self.participantImageURLs = participantImageURLs
        self.action = action
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            Group {
                if let action {
                    Button(action: action) {
                        content
                    }
                    .buttonStyle(.plain)
                } else {
                    content
                }
            }
            .fixedSize(horizontal: true, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.top, 0)
        .padding(.bottom, 1)
    }

    private var content: some View {
        VStack(spacing: 0) {
            avatarView
                .zIndex(1)

            HStack(spacing: 4) {
                Text(displayTitle)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(threadPillBackground)
            .overlay(threadPillStroke)
            .offset(y: -7)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                    .offset(y: -4)
            }
        }
        .frame(maxWidth: 220)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var avatarView: some View {
        if resolvedParticipantTitles.count > 1 {
            RotaryConversationGroupAvatarView(
                titles: resolvedParticipantTitles,
                imageURLs: resolvedParticipantImageURLs,
                size: avatarSize
            )
        } else {
            RotaryAvatarView(
                title: resolvedParticipantTitles.first ?? title,
                size: avatarSize,
                imageURL: resolvedParticipantImageURLs.first ?? imageURL
            )
        }
    }

    private var displayTitle: String {
        resolvedParticipantTitles.count > 1 ? "\(resolvedParticipantTitles.count) People" : title
    }

    private var resolvedParticipantTitles: [String] {
        let explicit = participantTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !explicit.isEmpty {
            return explicit
        }

        let candidate = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard candidate.contains(",") || candidate.contains("&") else {
            return [candidate]
        }

        return candidate
            .replacingOccurrences(of: " & ", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var resolvedParticipantImageURLs: [String] {
        let explicit = participantImageURLs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !explicit.isEmpty {
            return explicit
        }
        guard let imageURL, !imageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return [imageURL]
    }

    @ViewBuilder
    private var threadPillBackground: some View {
        if #available(iOS 26, *) {
            Capsule(style: .continuous)
                .fill(.clear)
                .glassEffect(
                    .regular.tint(.white.opacity(0.12)).interactive(action != nil),
                    in: .capsule
                )
        } else {
            Capsule(style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground).opacity(0.36))
        }
    }

    private var threadPillStroke: some View {
        Capsule(style: .continuous)
            .stroke(Color.white.opacity(0.20), lineWidth: 1)
    }

}

private struct RotaryConversationGroupAvatarView: View {
    let titles: [String]
    let imageURLs: [String]
    let size: CGFloat

    private var primaryTitle: String {
        titles.first ?? "?"
    }

    private var secondaryTitle: String? {
        guard titles.count > 1 else { return nil }
        return titles[1]
    }

    private var primaryImageURL: String? {
        imageURLs.first
    }

    private var secondaryImageURL: String? {
        guard imageURLs.count > 1 else { return nil }
        return imageURLs[1]
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RotaryAvatarView(title: primaryTitle, size: size, imageURL: primaryImageURL)

            if let secondaryTitle {
                RotaryAvatarView(
                    title: secondaryTitle,
                    size: max(size * 0.52, 14),
                    imageURL: secondaryImageURL
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.92), lineWidth: 1.5)
                )
                .offset(x: 3, y: 3)
            }
        }
        .frame(width: size + 8, height: size + 8)
    }
}

struct RotaryConversationPrincipalHeader: View {
    let title: String
    let subtitle: String?
    let avatarSize: CGFloat
    let imageURL: String?
    let action: (() -> Void)?

    init(
        title: String,
        subtitle: String? = nil,
        avatarSize: CGFloat = 42,
        imageURL: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.avatarSize = avatarSize
        self.imageURL = imageURL
        self.action = action
    }

    var body: some View {
        if let action {
            Button(action: action) {
                headerBody
            }
            .buttonStyle(.plain)
        } else {
            headerBody
        }
    }

    private var headerBody: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: 8) {
                    headerContent
                }
            } else {
                headerContent
            }
        }
        .contentShape(Rectangle())
    }

    private var headerContent: some View {
        VStack(spacing: 4) {
            RotaryAvatarView(title: title, size: avatarSize, imageURL: imageURL)

            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .frame(maxWidth: 232)
        .padding(.top, 2)
    }
}
