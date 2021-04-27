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
        var endIndex = content.endIndex
        var suffix = ""
        for (index, char) in content.enumerated().lazy {
            let didMeetLineBreak = char == "\n"
            let didReachMaxLength = index == 60
            if didMeetLineBreak || didReachMaxLength {
                endIndex = content.index(content.startIndex, offsetBy: index)
                if didReachMaxLength {
                    suffix = "..."
                }
                break
            }
        }
        let fragment = String(content[content.startIndex..<endIndex])
        let text = MarkdownConverter.plainText(from: fragment)
        return text + suffix
    }
    
}
