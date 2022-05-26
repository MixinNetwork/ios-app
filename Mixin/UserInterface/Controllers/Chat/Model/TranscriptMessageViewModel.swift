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
        R.string.localizable.transcript()
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
        switch MessageCategory(rawValue: content.category) {
        case .SIGNAL_TEXT, .PLAIN_TEXT, .ENCRYPTED_TEXT:
            digest += content.content ?? " "
        case .SIGNAL_IMAGE, .PLAIN_IMAGE, .ENCRYPTED_IMAGE:
            digest += R.string.localizable.content_photo()
        case .SIGNAL_VIDEO, .PLAIN_VIDEO, .ENCRYPTED_VIDEO:
            digest += R.string.localizable.content_video()
        case .SIGNAL_DATA, .PLAIN_DATA, .ENCRYPTED_DATA:
            digest += R.string.localizable.content_file()
        case .SIGNAL_STICKER, .PLAIN_STICKER, .ENCRYPTED_STICKER:
            digest += R.string.localizable.content_sticker()
        case .SIGNAL_CONTACT, .PLAIN_CONTACT, .ENCRYPTED_CONTACT:
            digest += R.string.localizable.content_contact()
        case .SIGNAL_AUDIO, .PLAIN_AUDIO, .ENCRYPTED_AUDIO:
            digest += R.string.localizable.content_audio()
        case .SIGNAL_LIVE, .PLAIN_LIVE, .ENCRYPTED_LIVE:
            digest += R.string.localizable.content_live()
        case .SIGNAL_POST, .PLAIN_POST, .ENCRYPTED_POST:
            digest += content.content ?? " "
        case .SIGNAL_LOCATION, .PLAIN_LOCATION, .ENCRYPTED_LOCATION:
            digest += R.string.localizable.content_location()
        case .APP_CARD:
            if let json = content.content?.data(using: .utf8), let card = try? JSONDecoder.default.decode(AppCardData.self, from: json) {
                digest += "[\(card.title)]"
            }
        default:
            digest += R.string.localizable.content_unknown()
        }
        return digest
    }
    
}
