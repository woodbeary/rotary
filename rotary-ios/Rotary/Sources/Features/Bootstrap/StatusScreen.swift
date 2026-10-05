import SwiftUI

enum StatusScreenKind {
    case pending
    case blocked(String)

    var eyebrow: String {
        switch self {
        case .pending:
            return "Pending"
        case .blocked:
            return "Workspace"
        }
    }
}

struct StatusScreen: View {
    let kind: StatusScreenKind
    let notice: MobileStatusNotice?
    let error: MobileErrorState?
    let retry: () -> Void
    let signOut: () -> Void

    init(kind: StatusScreenKind, notice: MobileStatusNotice, retry: @escaping () -> Void, signOut: @escaping () -> Void) {
        self.kind = kind
        self.notice = notice
        self.error = nil
        self.retry = retry
        self.signOut = signOut
    }

    init(kind: StatusScreenKind, error: MobileErrorState, retry: @escaping () -> Void, signOut: @escaping () -> Void) {
        self.kind = kind
        self.notice = nil
        self.error = error
        self.retry = retry
        self.signOut = signOut
    }

    var body: some View {
        let title = notice?.title ?? error?.title ?? "Rotary"
        let message = notice?.message ?? error?.message ?? "The workspace is unavailable."
        let detail = notice?.detail ?? error?.detail

        RotaryCenteredShell {
            RotaryGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(kind.eyebrow.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RotaryTheme.accent)
                    Text(title)
                        .font(.largeTitle.weight(.bold))
                    Text(message)
                        .foregroundStyle(.secondary)
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Try again", action: retry)
                    .buttonStyle(RotaryPrimaryButtonStyle())

                Button("Sign out", action: signOut)
                    .buttonStyle(RotarySecondaryButtonStyle())
            }
        }
    }
}
