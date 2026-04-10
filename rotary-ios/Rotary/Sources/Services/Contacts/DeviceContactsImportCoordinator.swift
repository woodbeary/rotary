import Contacts
import Foundation

actor DeviceContactsImportCoordinator {
    private let contactStore = CNContactStore()

    func fetchCandidates(limit: Int = 300) throws -> [DeviceContactImportCandidate] {
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
            return []
        }

        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.unifyResults = true

        var seenPhoneNumbers = Set<String>()
        var candidates: [DeviceContactImportCandidate] = []

        try contactStore.enumerateContacts(with: request) { contact, stop in
            if candidates.count >= limit {
                stop.pointee = true
                return
            }

            guard let phoneValue = contact.phoneNumbers.first?.value.stringValue,
                  let canonicalPhone = canonicalPhone(from: phoneValue),
                  !canonicalPhone.isEmpty else {
                return
            }

            guard seenPhoneNumbers.insert(canonicalPhone).inserted else {
                return
            }

            let name = resolvedName(for: contact)
            let email = contact.emailAddresses.first?.value as String?

            candidates.append(
                DeviceContactImportCandidate(
                    id: canonicalPhone,
                    name: name,
                    phoneNumber: canonicalPhone,
                    email: email?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyTrimmed
                )
            )
        }

        return candidates
    }

    private func resolvedName(for contact: CNContact) -> String? {
        let joinedName = [contact.givenName.nonEmptyTrimmed, contact.familyName.nonEmptyTrimmed]
            .compactMap { $0 }
            .joined(separator: " ")
            .nonEmptyTrimmed

        if let joinedName {
            return joinedName
        }

        return contact.organizationName.nonEmptyTrimmed
    }

    private func canonicalPhone(from raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }

        if digits.count == 11, digits.hasPrefix("1") {
            return "+\(digits)"
        }
        if digits.count == 10 {
            return "+1\(digits)"
        }
        return "+\(digits)"
    }
}

private extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
