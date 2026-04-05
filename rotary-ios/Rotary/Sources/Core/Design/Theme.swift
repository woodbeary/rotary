import SwiftUI
import UIKit

enum RotaryTheme {
    static let accent = Color(uiColor: .systemBlue)
    static let callAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.26, green: 0.74, blue: 0.44, alpha: 1)
            : UIColor(red: 0.20, green: 0.64, blue: 0.34, alpha: 1)
    })
    static let warning = Color(uiColor: UIColor { _ in
        .systemOrange
    })
    static let destructive = Color(uiColor: UIColor { _ in
        .systemRed
    })
    static let tint = Color(uiColor: .systemBlue)
    static let backgroundTop = dynamicColor(
        light: UIColor(red: 0.97, green: 0.975, blue: 0.985, alpha: 1),
        dark: UIColor(red: 0.145, green: 0.155, blue: 0.19, alpha: 1)
    )
    static let backgroundBottom = dynamicColor(
        light: UIColor(red: 0.93, green: 0.945, blue: 0.97, alpha: 1),
        dark: UIColor(red: 0.17, green: 0.18, blue: 0.22, alpha: 1)
    )
    static let cardStroke = dynamicColor(
        light: UIColor.separator.withAlphaComponent(0.10),
        dark: UIColor.separator.withAlphaComponent(0.22)
    )
    static let cardFill = dynamicColor(
        light: UIColor(red: 1, green: 1, blue: 1, alpha: 0.78),
        dark: UIColor(red: 0.19, green: 0.20, blue: 0.24, alpha: 0.72)
    )
    static let secondarySurface = dynamicColor(
        light: UIColor(red: 1, green: 1, blue: 1, alpha: 0.72),
        dark: UIColor(red: 0.19, green: 0.20, blue: 0.24, alpha: 0.64)
    )
    static let elevatedSurface = dynamicColor(
        light: UIColor(red: 1, green: 1, blue: 1, alpha: 0.92),
        dark: UIColor(red: 0.22, green: 0.23, blue: 0.27, alpha: 0.76)
    )
    static let elevatedStroke = dynamicColor(
        light: UIColor.separator.withAlphaComponent(0.10),
        dark: UIColor.separator.withAlphaComponent(0.20)
    )
    static let softSurface = dynamicColor(
        light: UIColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 0.92),
        dark: UIColor(red: 0.21, green: 0.22, blue: 0.26, alpha: 0.66)
    )
    static let subtleSurface = dynamicColor(
        light: UIColor(red: 0.90, green: 0.92, blue: 0.96, alpha: 0.92),
        dark: UIColor(red: 0.23, green: 0.24, blue: 0.29, alpha: 0.68)
    )
    static let incomingBubble = dynamicColor(
        light: UIColor(red: 0.98, green: 0.985, blue: 0.995, alpha: 0.94),
        dark: UIColor(red: 0.20, green: 0.21, blue: 0.25, alpha: 0.70)
    )
    static let nestedBubble = dynamicColor(
        light: UIColor(red: 0.95, green: 0.965, blue: 0.985, alpha: 0.96),
        dark: UIColor(red: 0.22, green: 0.23, blue: 0.27, alpha: 0.72)
    )
    static let inactivePillFill = dynamicColor(
        light: UIColor(red: 0.92, green: 0.935, blue: 0.96, alpha: 0.88),
        dark: UIColor(red: 0.25, green: 0.26, blue: 0.31, alpha: 0.92)
    )
    static let fieldFill = dynamicColor(
        light: UIColor(red: 1, green: 1, blue: 1, alpha: 0.92),
        dark: UIColor(red: 0.19, green: 0.20, blue: 0.24, alpha: 0.70)
    )
    static let fieldStroke = dynamicColor(
        light: UIColor.separator.withAlphaComponent(0.10),
        dark: UIColor.separator.withAlphaComponent(0.18)
    )
    static let placeholderText = dynamicColor(
        light: UIColor.secondaryLabel,
        dark: UIColor(red: 0.60, green: 0.63, blue: 0.69, alpha: 1)
    )
    static let avatarTint = dynamicColor(
        light: UIColor.systemGray5,
        dark: UIColor.systemGray4.withAlphaComponent(0.55)
    )
    static let chromeFill = dynamicColor(
        light: UIColor(red: 1, green: 1, blue: 1, alpha: 0.78),
        dark: UIColor(red: 0.19, green: 0.20, blue: 0.24, alpha: 0.64)
    )
    static let chromeStroke = dynamicColor(
        light: UIColor.separator.withAlphaComponent(0.10),
        dark: UIColor.separator.withAlphaComponent(0.18)
    )
    static let backdropPrimaryOrb = Color.clear
    static let backdropSecondaryOrb = Color.clear
    static let shadow = dynamicColor(
        light: UIColor.black.withAlphaComponent(0.08),
        dark: UIColor.black.withAlphaComponent(0.12)
    )
    static let muted = Color.secondary

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

@MainActor
enum RotaryHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func lightTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func softTap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.82)
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

struct RotaryBackdrop: View {
    let onTap: (() -> Void)?

    init(onTap: (() -> Void)? = nil) {
        self.onTap = onTap
    }

    var body: some View {
        let background = ZStack {
            LinearGradient(
                colors: [
                    RotaryTheme.backgroundTop,
                    RotaryTheme.backgroundBottom,
                    RotaryTheme.backgroundTop,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(RotaryTheme.accent.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 96)
                .offset(x: 150, y: -250)

            Circle()
                .fill(Color(uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark
                        ? UIColor(red: 0.78, green: 0.82, blue: 0.92, alpha: 0.10)
                        : UIColor(white: 1, alpha: 0.34)
                }))
                .frame(width: 240, height: 240)
                .blur(radius: 110)
                .offset(x: -150, y: -220)

            Circle()
                .fill(RotaryTheme.callAccent.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 132)
                .offset(x: -160, y: 260)

            Circle()
                .fill(Color(uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark
                        ? UIColor(red: 0.78, green: 0.82, blue: 0.92, alpha: 0.05)
                        : UIColor(white: 1, alpha: 0.09)
                }))
                .frame(width: 260, height: 260)
                .blur(radius: 120)
                .offset(x: 120, y: 260)
        }

        Group {
            if let onTap {
                background
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTap)
            } else {
                background
            }
        }
        .ignoresSafeArea()
    }
}

@MainActor
enum RotaryKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

enum RotaryDebugFlags {
    static var forceSkeletonPlaceholders: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-rotary-force-skeleton-placeholders")
#else
        false
#endif
    }
}

struct RotaryGlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder var content: Content

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: 20) {
                    glassInner
                        .glassEffect(
                            .regular.tint(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.12)).interactive(false),
                            in: .rect(cornerRadius: 22)
                        )
                }
            } else {
                fallbackInner
                    .background(
                        RotaryTheme.secondarySurface,
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(RotaryTheme.cardStroke, lineWidth: 1)
                    )
            }
        }
    }

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
        }
    }

    private var glassInner: some View {
        contentStack
            .padding(20)
            .background(
                Color.white.opacity(colorScheme == .dark ? 0.015 : 0.18),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .shadow(color: RotaryTheme.shadow, radius: 6, x: 0, y: 3)
    }

    private var fallbackInner: some View {
        contentStack
        .padding(20)
        .background(RotaryTheme.cardFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: RotaryTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

struct RotaryPill: View {
    let text: String
    let active: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(active ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(active ? RotaryTheme.accent : RotaryTheme.inactivePillFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(RotaryTheme.cardStroke.opacity(active ? 0 : 1), lineWidth: 1)
            )
    }
}

struct RotaryPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(RotaryTheme.accent.opacity(configuration.isPressed ? 0.8 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

enum RotaryGlassIconShape {
    case roundedRect
    case circle
}

struct RotaryGlassIcon: View {
    let systemName: String
    let size: CGFloat
    let frameSize: CGFloat
    let shape: RotaryGlassIconShape

    init(
        systemName: String,
        size: CGFloat = 18,
        frameSize: CGFloat = 36,
        shape: RotaryGlassIconShape = .roundedRect
    ) {
        self.systemName = systemName
        self.size = size
        self.frameSize = frameSize
        self.shape = shape
    }

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                iconLabel
                    .glassEffect(
                        .regular.tint(.white.opacity(shape == .circle ? 0.14 : 0.10)).interactive(),
                        in: glassShape
                    )
            } else {
                iconLabel
                    .background(RotaryTheme.secondarySurface, in: fallbackShape)
                    .overlay(
                        fallbackShape
                            .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
                    )
            }
        }
        .foregroundStyle(.primary)
    }

    private var iconLabel: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .frame(
                width: shape == .circle ? frameSize : frameSize + 6,
                height: frameSize
            )
    }

    private var glassShape: AnyInsettableShape {
        switch shape {
        case .roundedRect:
            AnyInsettableShape(
                UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 16,
                style: .continuous
                )
            )
        case .circle:
            AnyInsettableShape(Circle())
        }
    }

    private var fallbackShape: some InsettableShape {
        switch shape {
        case .roundedRect:
            AnyInsettableShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .circle:
            AnyInsettableShape(Circle())
        }
    }
}

struct RotaryGlassIconButton: View {
    let systemName: String
    let size: CGFloat
    let frameSize: CGFloat
    let shape: RotaryGlassIconShape
    let action: () -> Void

    init(
        systemName: String,
        size: CGFloat = 18,
        frameSize: CGFloat = 36,
        shape: RotaryGlassIconShape = .roundedRect,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.size = size
        self.frameSize = frameSize
        self.shape = shape
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            RotaryGlassIcon(
                systemName: systemName,
                size: size,
                frameSize: frameSize,
                shape: shape
            )
        }
        .buttonStyle(RotaryPressScaleButtonStyle())
    }
}

struct RotaryGlassTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if #available(iOS 26, *) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .glassEffect(.regular.tint(.white.opacity(0.22)).interactive(), in: .capsule)
                } else {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(RotaryTheme.secondarySurface, in: Capsule())
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
                        )
                }
            }
            .foregroundStyle(.primary)
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(RotaryPressScaleButtonStyle(pressedScale: 0.97))
    }
}

struct RotaryScreenHeading: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RotaryInlineStatusHeader: View {
    let subtitle: String?

    var body: some View {
        Group {
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct RotaryGlassMenuChip: View {
    let title: String?
    let systemName: String
    let showsChevron: Bool

    init(
        title: String? = nil,
        systemName: String,
        showsChevron: Bool = true
    ) {
        self.title = title
        self.systemName = systemName
        self.showsChevron = showsChevron
    }

    var body: some View {
        if title == nil && !showsChevron {
            RotaryGlassIcon(systemName: systemName, size: 17, frameSize: 36, shape: .roundedRect)
        } else {
            Group {
                if #available(iOS 26, *) {
                    label
                        .glassEffect(.regular.tint(.white.opacity(0.22)).interactive(), in: .capsule)
                } else {
                    label
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
                        )
                }
            }
            .foregroundStyle(.primary)
        }
    }

    private var label: some View {
        HStack(spacing: title == nil ? 0 : 8) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))

            if let title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            }

            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, title == nil ? 11 : 12)
        .frame(height: 38)
    }
}

struct RotaryFloatingActionButton: View {
    let systemName: String
    let tint: Color
    let action: () -> Void

    init(
        systemName: String,
        tint: Color = RotaryTheme.accent,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if #available(iOS 26, *) {
                    Image(systemName: systemName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .glassEffect(.regular.tint(tint.opacity(0.36)).interactive(), in: .circle)
                } else {
                    Image(systemName: systemName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(tint, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(tint.opacity(0.08), lineWidth: 1)
                    )
                }
            }
            .shadow(color: RotaryTheme.shadow, radius: 10, x: 0, y: 6)
        }
        .frame(width: 72, height: 72)
        .contentShape(Circle())
        .buttonStyle(RotaryPressScaleButtonStyle())
    }
}

struct RotaryPressScaleButtonStyle: ButtonStyle {
    let pressedScale: CGFloat

    init(pressedScale: CGFloat = 0.94) {
        self.pressedScale = pressedScale
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

struct RotarySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(RotaryTheme.secondarySurface.opacity(configuration.isPressed ? 0.76 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(RotaryTheme.cardStroke, lineWidth: 1)
            )
    }
}

struct RotaryTextFieldStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .foregroundStyle(.primary)
            .tint(RotaryTheme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(RotaryTheme.fieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(RotaryTheme.fieldStroke, lineWidth: 1)
            )
    }
}

extension View {
    func rotaryTextFieldStyle() -> some View {
        modifier(RotaryTextFieldStyleModifier())
    }
}

struct RotarySearchField: View {
    @Binding var text: String

    let prompt: String
    let onMic: (() -> Void)?

    init(
        text: Binding<String>,
        prompt: String,
        onMic: (() -> Void)? = nil
    ) {
        _text = text
        self.prompt = prompt
        self.onMic = onMic
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if text.isEmpty {
                if let onMic {
                    Button(action: onMic) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    RotaryHaptics.selection()
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .background(searchFieldBackground)
    }

    @ViewBuilder
    private var searchFieldBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(.white.opacity(0.14)).interactive(), in: .rect(cornerRadius: 22))
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(RotaryTheme.incomingBubble)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
                )
        }
    }
}

struct RotaryComposerBar<MenuContent: View>: View {
    @Binding var text: String

    let placeholder: String
    let maxLines: ClosedRange<Int>
    let isWorking: Bool
    let isFocused: FocusState<Bool>.Binding?
    let showsMenu: Bool
    let onMic: (() -> Void)?
    let onSend: () -> Void
    @ViewBuilder let menuContent: () -> MenuContent

    init(
        text: Binding<String>,
        placeholder: String,
        maxLines: ClosedRange<Int> = 1 ... 6,
        isWorking: Bool = false,
        isFocused: FocusState<Bool>.Binding? = nil,
        showsMenu: Bool = true,
        onMic: (() -> Void)? = nil,
        onSend: @escaping () -> Void,
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) {
        _text = text
        self.placeholder = placeholder
        self.maxLines = maxLines
        self.isWorking = isWorking
        self.isFocused = isFocused
        self.showsMenu = showsMenu
        self.onMic = onMic
        self.onSend = onSend
        self.menuContent = menuContent
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var showingSend: Bool {
        !trimmedText.isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if showsMenu {
                Menu(content: menuContent) {
                    RotaryGlassIcon(systemName: "plus", size: 18, frameSize: 42, shape: .circle)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .bottom, spacing: 8) {
                composerField

                if showingSend {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(RotaryTheme.accent)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                } else if let onMic {
                    Button(action: onMic) {
                        Image(systemName: "waveform")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .padding(.vertical, 7)
            .frame(minHeight: 52)
            .background(composerBackground)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)

                Rectangle()
                    .fill(RotaryTheme.chromeStroke)
                    .frame(height: 1 / UIScreen.main.scale)
                    .opacity(0.55)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private var composerField: some View {
        let field = ZStack(alignment: .topLeading) {
            if !placeholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .foregroundStyle(RotaryTheme.placeholderText)
                    .padding(.top, 8)
                    .padding(.leading, 5)
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .frame(height: editorHeight)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .foregroundStyle(.primary)
                .tint(RotaryTheme.accent)
                .padding(.horizontal, 1)
                .padding(.vertical, 2)
        }
        .frame(height: editorHeight, alignment: .leading)

        if let isFocused {
            field
                .focused(isFocused)
        } else {
            field
        }
    }

    @ViewBuilder
    private var composerBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(.white.opacity(0.16)).interactive(), in: .rect(cornerRadius: 24))
        } else {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(RotaryTheme.fieldFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
                )
        }
    }

    private var editorMaxHeight: CGFloat {
        let lineHeight: CGFloat = 22
        let verticalPadding: CGFloat = 10
        return CGFloat(maxLines.upperBound) * lineHeight + verticalPadding
    }

    private var editorHeight: CGFloat {
        let lineHeight: CGFloat = 22
        let baseHeight: CGFloat = 28
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let explicitLines = max(1, normalized.components(separatedBy: "\n").count)
        let wrappedLines = max(1, Int(ceil(Double(normalized.count) / 28.0)))
        let estimatedLines = max(explicitLines, wrappedLines)
        let clampedLines = min(max(estimatedLines, maxLines.lowerBound), maxLines.upperBound)
        return max(baseHeight, CGFloat(clampedLines) * lineHeight)
    }
}

enum RotaryDateFormatting {
    private static func makeISO8601Formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    static func parse(_ value: String) -> Date? {
        makeISO8601Formatter().date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    static func messageTimestamp(_ value: String) -> String {
        guard let date = parse(value) else { return "" }
        if Calendar.current.isDateInToday(date) {
            return date.formatted(.dateTime.hour().minute())
        }
        return date.formatted(.dateTime.month().day().hour().minute())
    }

    static func listTimestamp(_ value: String) -> String {
        guard let date = parse(value) else { return "" }
        return relativeTimestamp(for: date)
    }

    static func relativeTimestamp(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(.dateTime.hour().minute())
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        }
        if let weekAgo = Calendar.current.date(byAdding: .day, value: -6, to: Date()),
           date >= weekAgo {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(.dateTime.month().day())
    }

    static func dayKey(for date: Date?) -> String {
        guard let date else { return UUID().uuidString }
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    static func dayDividerLabel(for date: Date?) -> String {
        guard let date else { return "" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        if let weekAgo = calendar.date(byAdding: .day, value: -6, to: Date()),
           date >= weekAgo {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(.dateTime.month().day())
    }
}

struct RotaryCenteredShell<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() })
            VStack {
                Spacer(minLength: 28)
                content
                    .frame(maxWidth: 460)
                Spacer(minLength: 28)
            }
            .padding(.horizontal, 20)
        }
    }
}

struct AnyInsettableShape: InsettableShape {
    private let _path: @Sendable (CGRect) -> Path
    private let _inset: @Sendable (CGFloat) -> AnyInsettableShape

    init<S: InsettableShape>(_ shape: S) {
        _path = { rect in shape.path(in: rect) }
        _inset = { amount in AnyInsettableShape(shape.inset(by: amount)) }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }

    func inset(by amount: CGFloat) -> AnyInsettableShape {
        _inset(amount)
    }
}

struct RotarySkeletonList: View {
    let rows: Int
    let showTimestamp: Bool

    init(rows: Int = 6, showTimestamp: Bool = true) {
        self.rows = rows
        self.showTimestamp = showTimestamp
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { index in
                HStack(spacing: 12) {
                    Circle()
                        .fill(RotaryTheme.softSurface)
                        .frame(width: 50, height: 50)

                    VStack(alignment: .leading, spacing: 9) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(RotaryTheme.softSurface)
                            .frame(width: 118, height: 14)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(RotaryTheme.softSurface.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .frame(height: 12)
                    }

                    if showTimestamp {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(RotaryTheme.softSurface)
                            .frame(width: 54, height: 12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .redacted(reason: .placeholder)

                if index < rows - 1 {
                    Divider()
                        .padding(.leading, 78)
                }
            }
        }
    }
}

struct RotaryConversationSkeleton: View {
    let rows: Int

    init(rows: Int = 6) {
        self.rows = rows
    }

    var body: some View {
        VStack(spacing: 14) {
            ForEach(0..<rows, id: \.self) { index in
                HStack {
                    if index.isMultiple(of: 2) {
                        Spacer(minLength: 52)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(index.isMultiple(of: 2) ? RotaryTheme.accent.opacity(0.22) : RotaryTheme.softSurface)
                            .frame(width: index.isMultiple(of: 2) ? 184 : 158, height: 15)

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(index.isMultiple(of: 2) ? RotaryTheme.accent.opacity(0.18) : RotaryTheme.softSurface.opacity(0.86))
                            .frame(width: index.isMultiple(of: 2) ? 132 : 112, height: 12)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .frame(maxWidth: 270, alignment: .leading)
                    .background(
                        index.isMultiple(of: 2) ? RotaryTheme.accent.opacity(0.18) : RotaryTheme.incomingBubble,
                        in: UnevenRoundedRectangle(
                            topLeadingRadius: 24,
                            bottomLeadingRadius: index.isMultiple(of: 2) ? 24 : 9,
                            bottomTrailingRadius: index.isMultiple(of: 2) ? 9 : 24,
                            topTrailingRadius: 24,
                            style: .continuous
                        )
                    )
                    .redacted(reason: .placeholder)

                    if !index.isMultiple(of: 2) {
                        Spacer(minLength: 52)
                    }
                }
            }
        }
    }
}
