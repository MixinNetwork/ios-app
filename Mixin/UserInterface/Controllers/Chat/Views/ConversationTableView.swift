import UIKit
import MixinServices

class ConversationTableView: UITableView {
    
    override var tableFooterView: UIView? {
        get {
            return super.tableFooterView
        }
        set {
            let adjustContentOffset: Bool
            if super.tableFooterView == nil && newValue != nil {
                let reachesBottomBeforeAppending = abs(contentOffset.y - bottomContentOffset.y) < 1
                super.tableFooterView = newValue
                layoutIfNeeded()
                let contentSizeBeyondsBottom = contentSize.height > frame.height - contentInset.vertical
                adjustContentOffset = reachesBottomBeforeAppending && contentSizeBeyondsBottom
            } else if let footerView = super.tableFooterView, newValue == nil {
                adjustContentOffset = (contentSize.height - footerView.frame.height - contentOffset.y) < frame.height
                super.tableFooterView = nil
            } else {
                adjustContentOffset = false
            }
            if adjustContentOffset {
                contentOffset = bottomContentOffset
            }
        }
    }
    
    var bottomDistance: CGFloat {
        return contentSize.height - contentOffset.y
    }
    
    var indicesForVisibleSectionHeaders: [Int] {
        guard let indexPaths = indexPathsForVisibleRows else {
            return []
        }
        let indices = indexPaths.map{ $0.section }
        return Array(Set(indices)).sorted(by: <)
    }
    
    private let animationDuration: TimeInterval = 0.3
    
    private var headerViewsAnimator: UIViewPropertyAnimator?
    private var bottomContentOffset: CGPoint {
        let y = contentSize.height
            + adjustedContentInset.bottom
            - AppDelegate.current.mainWindow.bounds.height
        return CGPoint(x: 0, y: max(-contentInset.top, y))
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        registerCells()
    }
    
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        registerCells()
    }
    
    func dequeueReusableCell(withMessage message: MessageItem, for indexPath: IndexPath) -> UITableViewCell {
        if message.status == MessageStatus.FAILED.rawValue {
            return dequeueReusableCell(withReuseId: .text, for: indexPath)
        } else if message.status == MessageStatus.UNKNOWN.rawValue {
            return dequeueReusableCell(withReuseId: .unknown, for: indexPath)
        } else {
            return dequeueReusableCell(withReuseId: ReuseId(category: message.category), for: indexPath)
        }
    }
    
    func dequeueReusableCell(withReuseId reuseId: ReuseId, for indexPath: IndexPath) -> UITableViewCell {
        dequeueReusableCell(withIdentifier: reuseId.rawValue, for: indexPath)
    }
    
    func messageCellForRow(at point: CGPoint) -> MessageCell? {
        guard let indexPath = indexPathForRow(at: point), let cell = cellForRow(at: indexPath) as? MessageCell else {
            return nil
        }
        let converted = cell.convert(point, from: self)
        if cell.contentFrame.contains(converted) {
            return cell
        } else {
            return nil
        }
    }
    
    func scrollToBottom(animated: Bool) {
        setContentOffset(bottomContentOffset, animated: animated)
    }
    
    func setContentOffsetYSafely(_ y: CGFloat) {
        let bottomContentOffsetY = bottomContentOffset.y
        if bottomContentOffsetY > -contentInset.top {
            let y = min(bottomContentOffsetY, max(-contentInset.top, y))
            self.contentOffset = CGPoint(x: 0, y: y)
        }
    }
    
    func setFloatingHeaderViewsHidden(_ hidden: Bool, animated: Bool, delay: TimeInterval = 0) {
        headerViewsAnimator?.stopAnimation(true)
        headerViewsAnimator?.finishAnimation(at: .current)
        if animated {
            headerViewsAnimator = UIViewPropertyAnimator(duration: animationDuration, curve: .linear, animations: {
                self.setFloatingHeaderViewsHidden(hidden)
            })
            headerViewsAnimator?.startAnimation(afterDelay: delay)
        } else {
            if delay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: {
                    self.setFloatingHeaderViewsHidden(hidden)
                })
            } else {
                setFloatingHeaderViewsHidden(hidden)
            }
        }
    }
    
    private func setFloatingHeaderViewsHidden(_ hidden: Bool) {
        var sections = indicesForVisibleSectionHeaders
        if hidden {
            var firstVisibleSection: Int?
            var firstVisibleHeaderView: UITableViewHeaderFooterView?
            for section in sections {
                if let headerView = headerView(forSection: section), headerView.frame.maxY >= contentOffset.y + contentInset.top {
                    firstVisibleSection = section
                    firstVisibleHeaderView = headerView
                    break
                }
            }
            if let firstVisibleSection = firstVisibleSection, let firstVisibleHeaderView = firstVisibleHeaderView {
                let fixedRect = rectForHeader(inSection: firstVisibleSection)
                let actualRect = firstVisibleHeaderView.frame
                if abs(fixedRect.origin.y - actualRect.origin.y) > 1, let index = sections.firstIndex(of: firstVisibleSection) {
                    // header is floating
                    sections.remove(at: index)
                    firstVisibleHeaderView.alpha = 0
                }
            }
        }
        for header in sections.compactMap(headerView) {
            header.alpha = 1
        }
    }
    
    private func registerCells() {
        register(UINib(nibName: "ConversationDateHeaderView", bundle: .main),
                 forHeaderFooterViewReuseIdentifier: ReuseId.header.rawValue)
        register(SystemMessageCell.self, forCellReuseIdentifier: ReuseId.system.rawValue)
        register(TextMessageCell.self, forCellReuseIdentifier: ReuseId.text.rawValue)
        register(PhotoMessageCell.self, forCellReuseIdentifier: ReuseId.photo.rawValue)
        register(StickerMessageCell.self, forCellReuseIdentifier: ReuseId.sticker.rawValue)
        register(UnknownMessageCell.self, forCellReuseIdentifier: ReuseId.unknown.rawValue)
        register(AppButtonGroupMessageCell.self, forCellReuseIdentifier: ReuseId.appButtonGroup.rawValue)
        register(VideoMessageCell.self, forCellReuseIdentifier: ReuseId.video.rawValue)
        register(IconPrefixedTextMessageCell.self, forCellReuseIdentifier: ReuseId.iconPrefixedText.rawValue)
        register(LiveMessageCell.self, forCellReuseIdentifier: ReuseId.live.rawValue)
        register(PostMessageCell.self, forCellReuseIdentifier: ReuseId.post.rawValue)
        register(TransferMessageCell.self, forCellReuseIdentifier: ReuseId.transfer.rawValue)
        register(AppCardMessageCell.self, forCellReuseIdentifier: ReuseId.appCard.rawValue)
        register(ContactMessageCell.self, forCellReuseIdentifier: ReuseId.contact.rawValue)
        register(DataMessageCell.self, forCellReuseIdentifier: ReuseId.data.rawValue)
        register(AudioMessageCell.self, forCellReuseIdentifier: ReuseId.audio.rawValue)
        register(LocationMessageCell.self, forCellReuseIdentifier: ReuseId.location.rawValue)
        register(TranscriptMessageCell.self, forCellReuseIdentifier: ReuseId.transcript.rawValue)
    }
    
}

extension ConversationTableView {
    
    enum ReuseId: String {
        
        static let systemMessageRepresentableMessageCategories: Set<String> = {
            let categories: [MessageCategory] = [
                .EXT_ENCRYPTION,
                .SYSTEM_CONVERSATION,
                .KRAKEN_PUBLISH,
                .KRAKEN_INVITE,
                .KRAKEN_CANCEL,
                .KRAKEN_DECLINE,
                .KRAKEN_END
            ]
            return Set(categories.map(\.rawValue))
        }()
        
        case text = "TextMessageCell"
        case photo = "PhotoMessageCell"
        case sticker = "StickerMessageCell"
        case data = "DataMessageCell"
        case transfer = "TransferMessageCell"
        case system = "SystemMessageCell"
        case unknown = "UnknownMessageCell"
        case unreadHint = "UnreadHintMessageCell"
        case appButtonGroup = "AppButtonGroupCell"
        case contact = "ContactMessageCell"
        case video = "VideoMessageCell"
        case appCard = "AppCardMessageCell"
        case audio = "AudioMessageCell"
        case live = "LiveMessageCell"
        case post = "PostMessageCell"
        case location = "LocationMessageCell"
        case iconPrefixedText = "IconPrefixedTextMessageCell"
        case transcript = "TranscriptMessageCell"
        case header = "DateHeader"
        
        init(category: String) {
            if category.hasSuffix("_TEXT") {
                self = .text
            } else if category.hasSuffix("_IMAGE") {
                self = .photo
            } else if category.hasSuffix("_STICKER") {
                self = .sticker
            } else if category.hasSuffix("_DATA") {
                self = .data
            } else if category.hasSuffix("_CONTACT") {
                self = .contact
            } else if category.hasSuffix("_VIDEO") {
                self = .video
            } else if category.hasSuffix("_AUDIO") {
                self = .audio
            } else if category.hasSuffix("_LIVE") {
                self = .live
            } else if category.hasSuffix("_POST") {
                self = .post
            } else if category.hasSuffix("_LOCATION") {
                self = .location
            } else if category.hasPrefix("WEBRTC_") || category == MessageCategory.MESSAGE_RECALL.rawValue {
                self = .iconPrefixedText
            } else if category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
                self = .transfer
            } else if category == MessageCategory.EXT_UNREAD.rawValue {
                self = .unreadHint
            } else if Self.systemMessageRepresentableMessageCategories.contains(category) {
                self = .system
            } else if category == MessageCategory.APP_BUTTON_GROUP.rawValue {
                self = .appButtonGroup
            } else if category == MessageCategory.APP_CARD.rawValue {
                self = .appCard
            } else if category == MessageCategory.SIGNAL_TRANSCRIPT.rawValue {
                self = .transcript
            } else {
                self = .unknown
            }
        }
    }
    
}
