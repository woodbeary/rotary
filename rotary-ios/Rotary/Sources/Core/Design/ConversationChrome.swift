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
                Text(initials)
                    .font(.system(size: size * 0.40, weight: .semibold))
                    .frame(width: size, height: size)
                    .background(RotaryTheme.softSurface, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
                    )
                    .shadow(color: RotaryTheme.shadow.opacity(0.08), radius: 4, x: 0, y: 2)
            }
        }
        .foregroundStyle(.primary)
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
    let action: (() -> Void)?

    init(
        title: String,
        subtitle: String? = nil,
        avatarSize: CGFloat = 56,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.avatarSize = avatarSize
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
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var content: some View {
        HStack(spacing: 12) {
            RotaryAvatarView(title: title, size: avatarSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(headerBackground)
        .overlay(headerStroke)
        .shadow(color: RotaryTheme.shadow.opacity(0.16), radius: 16, x: 0, y: 8)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var headerBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(.white.opacity(0.18)).interactive(), in: .rect(cornerRadius: 28))
        } else {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(RotaryTheme.secondarySurface.opacity(0.92))
        }
    }

    private var headerStroke: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(RotaryTheme.chromeStroke, lineWidth: 1)
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
