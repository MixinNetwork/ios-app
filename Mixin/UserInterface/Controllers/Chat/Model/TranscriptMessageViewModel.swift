import UIKit
import MixinServices

class TranscriptMessageViewModel: TextMessageViewModel {
    
    static let maxNumberOfDigestLines = 4
    static let transcriptBackgroundMargin = Margin(leading: -6, trailing: -5, top: 4, bottom: 2)
    static let transcriptInterlineSpacing: CGFloat = 4
    
    let contents: [TranscriptMessage.LocalContent]
    let digests: [String]
    
    private let transcriptInset = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
    
    private(set) var transcriptBackgroundFrame: CGRect = .zero
    private(set) var transcriptFrame: CGRect = .zero
    
    private var digestsHeight: CGFloat = 0
    
    override var rawContent: String {
        R.string.localizable.chat_transcript()
    }
    
    override var backgroundWidth: CGFloat {
        layoutWidth - DetailInfoMessageViewModel.bubbleMargin.horizontal
    }
    
    override init(message: MessageItem) {
        if let data = message.content?.data(using: .utf8), let contents = try? JSONDecoder.default.decode([TranscriptMessage.LocalContent].self, from: data) {
            self.contents = contents
        } else {
            self.contents = []
        }
        self.digests = self.contents
            .prefix(Self.maxNumberOfDigestLines)
            .map(Self.digest(of:))
        super.init(message: message)
    }
    
    override func linkRanges(from string: String) -> [Link.Range] {
        []
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        digestsHeight = Self.transcriptBackgroundMargin.vertical
            + CGFloat(digests.count - 1) * Self.transcriptInterlineSpacing
            + CGFloat(digests.count) * MessageFontSet.transcriptDigest.scaled.lineHeight
            + transcriptInset.vertical
        super.layout(width: width, style: style)
        transcriptBackgroundFrame = CGRect(x: contentLabelFrame.origin.x + Self.transcriptBackgroundMargin.leading,
                                           y: contentLabelFrame.maxY + Self.transcriptBackgroundMargin.top,
                                           width: backgroundWidth - contentAdditionalLeadingMargin - contentMargin.horizontal - Self.transcriptBackgroundMargin.horizontal,
                                           height: digestsHeight - Self.transcriptBackgroundMargin.bottom)
        transcriptFrame = transcriptBackgroundFrame.inset(by: transcriptInset)
    }
    
    override func adjustedContentSize(_ raw: CGSize) -> CGSize {
        return CGSize(width: raw.width, height: raw.height + digestsHeight)
    }
    
}

extension TranscriptMessageViewModel  {
    
    private static func digest(of content: TranscriptMessage.LocalContent) -> String {
        var digest: String
        if let username = content.name {
            digest = username + ": "
        } else {
            digest = ""
        }
        switch content.category {
        case .text:
            digest += content.content ?? " "
        case .image:
            digest += R.string.localizable.notification_content_photo()
        case .video:
            digest += R.string.localizable.notification_content_video()
        case .data:
            digest += R.string.localizable.notification_content_file()
        case .sticker:
            digest += R.string.localizable.notification_content_sticker()
        case .contact:
            digest += R.string.localizable.notification_content_contact()
        case .audio:
            digest += R.string.localizable.notification_content_audio()
        case .live:
            digest += R.string.localizable.notification_content_live()
        case .post:
            digest += content.content ?? " "
        case .location:
            digest += R.string.localizable.notification_content_location()
        case .appCard:
            if let json = content.content?.data(using: .utf8), let card = try? JSONDecoder.default.decode(AppCardData.self, from: json) {
                digest += "[\(card.title)]"
            }
        case .unknown:
            digest += R.string.localizable.notification_content_unknown()
        }
        return digest
    }
    
}
