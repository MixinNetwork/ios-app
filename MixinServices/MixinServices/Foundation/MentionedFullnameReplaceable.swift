import Foundation

public protocol MentionedFullnameReplaceable {
    
    var contentBeforeReplacingMentionedFullname: String? { get }
    var mentionsJson: Data? { get }
    var mentions: MessageMention.Mentions? { get }
    
    // Mentions ordered by key in descent
    // e.g. We got 2 mentions here, one is "7000101", another is "7000",
    // We must match token "7000101" first, or "7000101" in message content
    // will be partially matched by token of "7000"
    var sortedMentions: [(key: String, value: String)] { get }
    
}

extension MentionedFullnameReplaceable {
    
    public var mentions: MessageMention.Mentions? {
        guard let json = mentionsJson else {
            return nil
        }
        return try? JSONDecoder.default.decode(MessageMention.Mentions.self, from: json)
    }
    
    public var sortedMentions: [(key: String, value: String)] {
        mentions?.sorted(by: { $0.key > $1.key }) ?? []
    }
    
    func makeMentionedFullnameReplacedContent() -> String {
        guard let mentions = mentions, let content = contentBeforeReplacingMentionedFullname else {
            return contentBeforeReplacingMentionedFullname ?? ""
        }
        var replaced = content ?? ""
        for mention in sortedMentions {
            let target = "\(Mention.prefix)\(mention.key)"
            let replacement = "\(Mention.prefix)\(mention.value)"
            replaced = replaced.replacingOccurrences(of: target, with: replacement)
        }
        return replaced
    }
    
}
