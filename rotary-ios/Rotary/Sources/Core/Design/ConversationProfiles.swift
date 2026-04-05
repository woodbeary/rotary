import SwiftUI

struct RotaryProfileTabItem: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String?

    init(id: String, title: String, systemImage: String? = nil) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}

struct RotaryProfileTabBar: View {
    let items: [RotaryProfileTabItem]
    @Binding var selectedID: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    Button {
                        guard selectedID != item.id else { return }
                        RotaryHaptics.selection()
                        selectedID = item.id
                    } label: {
                        VStack(spacing: item.systemImage == nil ? 0 : 4) {
                            if let systemImage = item.systemImage {
                                Image(systemName: systemImage)
                                    .font(.system(size: 13, weight: .semibold))
                            }

                            Text(item.title)
                                .font(.caption2.weight(selectedID == item.id ? .semibold : .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedID == item.id ? Color.primary : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minWidth: item.systemImage == nil ? 52 : 64)
                        .background {
                            Capsule(style: .continuous)
                                .fill(selectedID == item.id ? RotaryTheme.chromeFill : Color.clear)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(
                                            selectedID == item.id ? RotaryTheme.chromeStroke : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
        }
    }
}

struct RotaryProfileHero<Actions: View>: View {
    let title: String
    let subtitle: String?
    let tertiaryText: String?
    let imageURL: String?
    @ViewBuilder let actions: Actions

    init(
        title: String,
        subtitle: String? = nil,
        tertiaryText: String? = nil,
        imageURL: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tertiaryText = tertiaryText
        self.imageURL = imageURL
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 14) {
            RotaryAvatarView(
                title: title,
                size: 102,
                imageURL: imageURL
            )

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let tertiaryText, !tertiaryText.isEmpty {
                    Text(tertiaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if !(Actions.self == EmptyView.self) {
                actions
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}

struct RotaryProfileActionButton: View {
    let title: String
    let systemImage: String
    let showsTitle: Bool
    let action: () -> Void

    init(
        title: String,
        systemImage: String,
        showsTitle: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.showsTitle = showsTitle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: showsTitle ? 8 : 0) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: showsTitle ? 42 : 46, height: showsTitle ? 42 : 46)
                    .foregroundStyle(.primary)
                    .background(RotaryTheme.chromeFill, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(RotaryTheme.chromeStroke, lineWidth: 1)
                    )

                if showsTitle {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}

struct RotaryProfileInfoCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        RotaryGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RotaryProfileMetaRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)

            Text(value)
                .font(.body.weight(.medium))
                .foregroundStyle(valueColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RotaryProfilePlaceholderCard: View {
    let title: String
    let systemImage: String

    var body: some View {
        RotaryGlassCard {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}
