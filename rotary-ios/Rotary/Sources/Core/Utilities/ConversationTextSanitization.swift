import Foundation

func rotarySanitizedConversationText(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\r", with: "")
        .replacingOccurrences(of: "\t", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func rotarySanitizedConversationPreview(_ value: String) -> String {
    rotarySanitizedConversationText(value)
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "  ", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
