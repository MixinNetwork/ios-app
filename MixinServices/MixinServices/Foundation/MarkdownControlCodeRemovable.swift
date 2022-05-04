import Foundation

protocol MarkdownControlCodeRemovable {
    
    var contentBeforeRemovingMarkdownControlCode: String? { get }
    var isPostContent: Bool { get }
    
}

extension MarkdownControlCodeRemovable {
    
    func makeMarkdownControlCodeRemovedContent() -> String {
        guard isPostContent, let content = contentBeforeRemovingMarkdownControlCode else {
            return contentBeforeRemovingMarkdownControlCode ?? ""
        }
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        var endIndex = trimmedContent.endIndex
        var suffix = ""
        for (index, char) in trimmedContent.enumerated().lazy {
            let didMeetLineBreak = char == "\n"
            let didReachMaxLength = index == 60
            if didMeetLineBreak || didReachMaxLength {
                endIndex = trimmedContent.index(trimmedContent.startIndex, offsetBy: index)
                if didReachMaxLength {
                    suffix = "..."
                }
                break
            }
        }
        let fragment = String(trimmedContent[content.startIndex..<endIndex])
        let text = MarkdownConverter.plainText(from: fragment)
        return text + suffix
    }
    
}
