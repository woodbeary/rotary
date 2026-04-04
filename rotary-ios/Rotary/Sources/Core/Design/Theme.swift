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
    static let backgroundTop = Color(uiColor: .systemBackground)
    static let backgroundBottom = Color(uiColor: .systemBackground)
    static let cardStroke = dynamicColor(
        light: UIColor.separator.withAlphaComponent(0.10),
        dark: UIColor.separator.withAlphaComponent(0.22)
    )
    static let cardFill = Color(uiColor: .secondarySystemGroupedBackground)
    static let secondarySurface = Color(uiColor: .secondarySystemGroupedBackground)
    static let elevatedSurface = Color(uiColor: .secondarySystemBackground)
    static let elevatedStroke = dynamicColor(
        light: UIColor.separator.withAlphaComponent(0.10),
        dark: UIColor.separator.withAlphaComponent(0.20)
    )
    static let softSurface = Color(uiColor: .tertiarySystemGroupedBackground)
    static let subtleSurface = Color(uiColor: .tertiarySystemFill)
    static let incomingBubble = Color(uiColor: .secondarySystemBackground)
    static let nestedBubble = Color(uiColor: .tertiarySystemBackground)
    static let inactivePillFill = Color(uiColor: .tertiarySystemFill)
    static let fieldFill = Color(uiColor: .secondarySystemBackground)
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
    static let chromeFill = Color(uiColor: .systemBackground)
    static let chromeStroke = dynamicColor(
        light: UIColor.separator.withAlphaComponent(0.10),
        dark: UIColor.separator.withAlphaComponent(0.18)
    )
    static let backdropPrimaryOrb = Color.clear
    static let backdropSecondaryOrb = Color.clear
    static let shadow = dynamicColor(
        light: UIColor.black.withAlphaComponent(0.08),
        dark: UIColor.black.withAlphaComponent(0.22)
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
        Group {
            if let onTap {
                RotaryTheme.backgroundTop
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTap)
            } else {
                RotaryTheme.backgroundTop
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

struct RotaryGlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: 20) {
                    inner
                        .glassEffect(.regular.tint(.white.opacity(0.12)).interactive(false), in: .rect(cornerRadius: 22))
                }
            } else {
                inner
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

    private var inner: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
        }
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

struct RotaryGlassIcon: View {
    let systemName: String
    let size: CGFloat
    let frameSize: CGFloat

    init(
        systemName: String,
        size: CGFloat = 18,
        frameSize: CGFloat = 36
    ) {
        self.systemName = systemName
        self.size = size
        self.frameSize = frameSize
    }

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                Image(systemName: systemName)
                    .font(.system(size: size, weight: .semibold))
                    .frame(width: frameSize, height: frameSize)
                    .glassEffect(.regular.tint(.white.opacity(0.24)).interactive(), in: .circle)
            } else {
                Image(systemName: systemName)
                    .font(.system(size: size, weight: .semibold))
                    .frame(width: frameSize, height: frameSize)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(RotaryTheme.elevatedStroke, lineWidth: 1)
                    )
            }
        }
        .foregroundStyle(.primary)
    }
}

struct RotaryGlassIconButton: View {
    let systemName: String
    let size: CGFloat
    let frameSize: CGFloat
    let action: () -> Void

    init(
        systemName: String,
        size: CGFloat = 18,
        frameSize: CGFloat = 36,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.size = size
        self.frameSize = frameSize
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            RotaryGlassIcon(
                systemName: systemName,
                size: size,
                frameSize: frameSize
            )
        }
        .buttonStyle(RotaryPressScaleButtonStyle())
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
            RotaryGlassIcon(systemName: systemName, size: 17, frameSize: 36)
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
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if text.isEmpty {
                if let onMic {
                    Button(action: onMic) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.tertiary)
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
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(searchFieldBackground)
    }

    @ViewBuilder
    private var searchFieldBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(.white.opacity(0.12)).interactive(), in: .rect(cornerRadius: 18))
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(RotaryTheme.incomingBubble)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
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
    let onMic: () -> Void
    let onSend: () -> Void
    @ViewBuilder let menuContent: () -> MenuContent

    init(
        text: Binding<String>,
        placeholder: String,
        maxLines: ClosedRange<Int> = 1 ... 6,
        isWorking: Bool = false,
        isFocused: FocusState<Bool>.Binding? = nil,
        showsMenu: Bool = true,
        onMic: @escaping () -> Void,
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
                    RotaryGlassIcon(systemName: "plus", size: 18, frameSize: 42)
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
                } else {
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
            .padding(.vertical, 8)
            .frame(minHeight: 54)
            .background(composerBackground)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background {
            Rectangle()
                .fill(Color(uiColor: .systemBackground))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(RotaryTheme.chromeStroke)
                        .frame(height: 1 / UIScreen.main.scale)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private var composerField: some View {
        let field = ZStack(alignment: .topLeading) {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
            Capsule(style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(.white.opacity(0.12)).interactive(), in: .capsule)
        } else {
            Capsule(style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(
                    Capsule(style: .continuous)
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
        if Calendar.current.isDateInToday(date) {
            return date.formatted(.dateTime.hour().minute())
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
            RotaryBackdrop()
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
