import Foundation

protocol MentionedFullnameReplaceable {
    
    var content: String { get }
    var mentionsJson: Data? { get }
    var mentions: MessageMention.Mentions? { get }
    
}

extension MentionedFullnameReplaceable {
    
    var mentions: MessageMention.Mentions? {
        guard let json = mentionsJson else {
            return nil
        }
        return try? JSONDecoder.default.decode(MessageMention.Mentions.self, from: json)
    }
    
    func makeMentionedFullnameReplacedContent() -> String {
        guard let mentions = mentions else {
            return content
        }
        var replaced = content
        for mention in mentions {
            let target = "\(Mention.prefix)\(mention.key)"
            let replacement = "\(Mention.prefix)\(mention.value)"
            replaced = replaced.replacingOccurrences(of: target, with: replacement)
        }
        return replaced
    }
    
}
