import Foundation

struct Language: Identifiable, Hashable {
    let id: String
    let name: String
    let englishName: String

    var base: String { String(id.prefix { $0 != "-" }) }
    var languageName: String { String(englishName.prefix { $0 != "(" }).trimmingCharacters(in: .whitespaces) }

    static let all: [Language] = [
        Language(id: "en-US", name: "English (US)", englishName: "English (US)"),
        Language(id: "en-GB", name: "English (UK)", englishName: "English (UK)"),
        Language(id: "en-AU", name: "English (Australia)", englishName: "English (Australia)"),
        Language(id: "en-CA", name: "English (Canada)", englishName: "English (Canada)"),
        Language(id: "es-ES", name: "Español (España)", englishName: "Spanish (Spain)"),
        Language(id: "es-MX", name: "Español (México)", englishName: "Spanish (Mexico)"),
        Language(id: "pt-BR", name: "Português (Brasil)", englishName: "Portuguese (Brazil)"),
        Language(id: "pt-PT", name: "Português (Portugal)", englishName: "Portuguese (Portugal)"),
        Language(id: "fr-FR", name: "Français (France)", englishName: "French (France)"),
        Language(id: "fr-CA", name: "Français (Canada)", englishName: "French (Canada)"),
        Language(id: "de-DE", name: "Deutsch", englishName: "German"),
        Language(id: "it-IT", name: "Italiano", englishName: "Italian"),
        Language(id: "nl-NL", name: "Nederlands", englishName: "Dutch"),
        Language(id: "ja-JP", name: "日本語", englishName: "Japanese"),
        Language(id: "zh-CN", name: "中文（简体）", englishName: "Chinese (Simplified)"),
        Language(id: "ko-KR", name: "한국어", englishName: "Korean"),
        Language(id: "ru-RU", name: "Русский", englishName: "Russian"),
        Language(id: "tr-TR", name: "Türkçe", englishName: "Turkish"),
        Language(id: "ar-SA", name: "العربية", englishName: "Arabic"),
        Language(id: "hi-IN", name: "हिन्दी", englishName: "Hindi"),
    ]

    static func named(_ id: String) -> Language {
        all.first { $0.id == id } ?? Language(id: id, name: id, englishName: id)
    }

    static func sameBase(_ a: String, _ b: String) -> Bool {
        named(a).base == named(b).base
    }
}

enum Level: String, CaseIterable, Identifiable, Codable {
    case beginner, intermediate, upperIntermediate = "upper-intermediate", advanced

    var id: String { rawValue }
    var label: String { rawValue.replacingOccurrences(of: "-", with: " ").capitalized }
}
