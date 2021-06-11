import Foundation

enum MentionConverter {
    
    // Due to historical reasons, we are using different serialization between database and transcript
    
    typealias LocalMentions = [String: String]
    
    private struct TranscriptMention: Codable {
        let fullName: String
        let identityNumber: String
    }
    
    static func transcriptMention(from localMention: Data?) -> String? {
        guard let localMention = localMention else {
            return nil
        }
        guard let decoded = try? JSONDecoder.default.decode(LocalMentions.self, from: localMention) else {
            return nil
        }
        let transcriptMentions = decoded.map { (key, value) in
            TranscriptMention(fullName: value, identityNumber: key)
        }
        guard let encoded = try? JSONEncoder.snakeCase.encode(transcriptMentions) else {
            return nil
        }
        return String(data: encoded, encoding: .utf8)
    }
    
    static func localMention(from transcriptMention: String?) -> Data? {
        guard let data = transcriptMention?.data(using: .utf8) else {
            return nil
        }
        guard let mentions = try? JSONDecoder.snakeCase.decode([TranscriptMention].self, from: data) else {
            return nil
        }
        var localMentions: [String: String] = [:]
        for mention in mentions {
            localMentions[mention.identityNumber] = mention.fullName
        }
        return try? JSONEncoder.default.encode(localMentions)
    }
    
}
