import PhotosUI
import SwiftUI
import UIKit

private enum RotaryContactEditorPalette {
    static let chromeFill = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.12, alpha: 1)
            : .secondarySystemBackground
    })

    static let chromeBorder = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.22, alpha: 1)
            : UIColor.separator.withAlphaComponent(0.12)
    })
}

struct RotaryContactDraft: Hashable {
    var contactId: String?
    var firstName: String
    var lastName: String
    var company: String
    var phoneNumber: String
    var email: String
    var fullAddress: String
    var avatarDataURL: String?

    var displayName: String {
        [firstName.nonEmptyTrimmed, lastName.nonEmptyTrimmed]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    var resolvedName: String? {
        displayName.nonEmptyTrimmed ?? company.nonEmptyTrimmed
    }
}

struct RotaryContactEditorScreen: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialDraft: RotaryContactDraft
    let onSave: (RotaryContactDraft) async throws -> MobileCreatedContact
    let onSaved: ((MobileCreatedContact) -> Void)?

    @State private var draft: RotaryContactDraft
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var selectedPhotoItem: PhotosPickerItem?

    init(
        title: String,
        initialDraft: RotaryContactDraft,
        onSave: @escaping (RotaryContactDraft) async throws -> MobileCreatedContact,
        onSaved: ((MobileCreatedContact) -> Void)? = nil
    ) {
        self.title = title
        self.initialDraft = initialDraft
        self.onSave = onSave
        self.onSaved = onSaved
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        let photoButtonTitle = draft.avatarDataURL == nil ? "Add Photo" : "Edit Photo"

        NavigationStack {
            ZStack {
                RotaryBackdrop(onTap: { RotaryKeyboard.dismiss() })

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 12) {
                            RotaryEditableAvatar(dataURL: draft.avatarDataURL, fallbackTitle: draft.displayName.isEmpty ? "?" : draft.displayName)

                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Text(photoButtonTitle)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 18)
                                    .frame(height: 42)
                                    .background(RotaryContactEditorPalette.chromeFill, in: Capsule())
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(RotaryContactEditorPalette.chromeBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 12)

                        RotaryContactFieldGroup {
                            TextField("First name", text: $draft.firstName)
                            Divider()
                            TextField("Last name", text: $draft.lastName)
                            Divider()
                            TextField("Company", text: $draft.company)
                        }

                        RotaryContactFieldGroup {
                            TextField("Phone", text: $draft.phoneNumber)
                                .keyboardType(.phonePad)
                            Divider()
                            TextField("Email", text: $draft.email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        RotaryContactFieldGroup {
                            TextField("Address", text: $draft.fullAddress, axis: .vertical)
                                .lineLimit(2 ... 4)
                        }

                        if let errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    RotaryContactEditorToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    RotaryContactEditorToolbarButton(systemName: isSaving ? "ellipsis" : "checkmark") {
                        Task { await save() }
                    }
                    .disabled(isSaving || draft.phoneNumber.nonEmptyTrimmed == nil)
                }
            }
        }
        .presentationDetents([.large])
        .task(id: selectedPhotoItem) {
            guard let selectedPhotoItem else { return }
            await loadPhoto(selectedPhotoItem)
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let contact = try await onSave(draft)
            RotaryHaptics.success()
            onSaved?(contact)
            dismiss()
        } catch {
            RotaryHaptics.error()
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let avatarDataURL = RotaryAvatarDataURL.encode(data: data)
            else {
                return
            }
            draft.avatarDataURL = avatarDataURL
            RotaryHaptics.selection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RotaryEditableAvatar: View {
    let dataURL: String?
    let fallbackTitle: String

    var body: some View {
        if let dataURL, let image = RotaryAvatarDataURL.decode(from: dataURL) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 112, height: 112)
                .clipShape(Circle())
        } else {
            RotaryAvatarView(title: fallbackTitle, size: 112)
        }
    }
}

private struct RotaryContactFieldGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .textInputAutocapitalization(.words)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 58)
        .background(RotaryContactEditorPalette.chromeFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(RotaryContactEditorPalette.chromeBorder, lineWidth: 1)
        )
    }
}

private struct RotaryContactEditorToolbarButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(RotaryContactEditorPalette.chromeFill, in: Circle())
                .overlay(
                    Circle()
                        .stroke(RotaryContactEditorPalette.chromeBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private enum RotaryAvatarDataURL {
    static func encode(data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        let targetSize = CGSize(width: 320, height: 320)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let jpegData = scaled.jpegData(compressionQuality: 0.78) else {
            return nil
        }
        return "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
    }

    static func decode(from value: String) -> UIImage? {
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

private extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
