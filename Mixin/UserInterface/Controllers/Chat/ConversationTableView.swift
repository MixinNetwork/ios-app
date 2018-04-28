import UIKit

extension Message {
    static let unreadHint = Message(type: .EXT_UNREAD, conversationId: "")
}

class ConversationTableView: RowHeightCalculableTableView {
    
    var contentSizeCache = [AnyHashable: CGSize]()

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect, style: UITableViewStyle) {
        super.init(frame: frame, style: style)
        prepare()
    }

    func dequeueReusableCell(withMessage message: Message, for indexPath: IndexPath) -> UITableViewCell {
        let reuseId = ReuseId(message: message)
        return dequeueReusableCell(withIdentifier: reuseId.rawValue, for: indexPath)
    }
    
    func contentSizeForCell(withMessage message: Message, cachedBy key: AnyHashable, configuration: @escaping (RowHeightCalculableTableViewCell) -> Void) -> CGSize {
        if let cachedSize = contentSizeCache[key] {
            return cachedSize
        } else {
            let size = contentSizeForCell(withMessage: message, configuration: configuration)
            contentSizeCache[key] = size
            return size
        }
    }
    
    func contentSizeForCell(withMessage message: Message, configuration: (RowHeightCalculableTableViewCell) -> Void) -> CGSize {
        let reuseId = ReuseId(message: message)
        if reuseId == .unreadHint {
            return CGSize(width: frame.width, height: heightForCell(withIdentifier: reuseId.rawValue, configuration: configuration))
        } else {
            let cell = templateCell(forReuseIdentifier: reuseId.rawValue)
            cell.prepareForReuse()
            configuration(cell)
            return cell.sizeThatFits(CGSize(width: frame.width, height: UILayoutFittingExpandedSize.height))
        }
    }

    private func prepare() {
        register(UINib(nibName: "ConversationDateHeaderView", bundle: .main),
                 forHeaderFooterViewReuseIdentifier: ReuseId.header.rawValue)
        register(TextMessageCell.self, forCellReuseIdentifier: ReuseId.text.rawValue)
        register(PhotoMessageCell.self, forCellReuseIdentifier: ReuseId.photo.rawValue)
    }
    
}

extension ConversationTableView {
    
    enum ReuseId: String {
        case text = "TextMessageCell"
        case photo = "PhotoMessageCell"
        case transfer = "TransferMessageCell"
        case header = "DateHeader"
        case unreadHint = "UnreadHintCell"
        case unknown = "UnknownMessageCell"
        
        init(message: Message) {
            switch message.category {
            case .TEXT:
                self = .text
            case .IMAGE:
                self = .photo
            case .TRANSFER:
                self = .transfer
            case .EXT_UNREAD:
                self = .unreadHint
            default:
                self = .unknown
            }
        }
    }
    
}
