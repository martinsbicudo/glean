import Foundation

struct SentenceCheck: Equatable, Decodable {
    var ok: Bool
    var corrected: String
    var explanation: String
    var better: [String]

    private enum CodingKeys: String, CodingKey { case ok, corrected, explanation, better }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decode(Bool.self, forKey: .ok)
        corrected = (try c.decodeIfPresent(String.self, forKey: .corrected) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        explanation = (try c.decodeIfPresent(String.self, forKey: .explanation) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        better = (try c.decodeIfPresent([String].self, forKey: .better) ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

extension AIJSON {
    static func sentence(from text: String) throws -> SentenceCheck {
        for data in candidates(text) {
            if let check = try? JSONDecoder().decode(SentenceCheck.self, from: data) { return check }
        }
        throw ParseError.noJSON
    }
}
