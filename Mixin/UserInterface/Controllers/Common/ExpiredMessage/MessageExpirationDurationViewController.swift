import UIKit
import Alamofire
import MixinServices

final class MessageExpirationDurationViewController: SettingsTableViewController {
    
    private let rows = Option.allCases.map { option in
        SettingsRow(title: option.title, accessory: .none)
    }
    
    private let conversation: ConversationItem
    private let canEdit: Bool
    
    private lazy var section = SettingsRadioSection(rows: rows)
    private lazy var dataSource = SettingsDataSource(sections: [section])
    
    private var currentExpireIn: Int64
    
    init(conversation: ConversationItem) {
        self.conversation = conversation
        self.currentExpireIn = conversation.expireIn
        self.canEdit = !conversation.isGroup()
        || ParticipantDAO.shared.isAdmin(conversationId: conversation.conversationId, userId: myUserId)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.disappearing_message()
        tableView.allowsSelection = canEdit && conversation.isExpirationResolved
        tableView.tableHeaderView = R.nib.expiredMessageTableHeaderView(withOwner: nil)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        reloadExpirationOptions()
        
        guard !conversation.isExpirationResolved else {
            return
        }
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.startAnimating()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: indicator)
        let conversationID = conversation.conversationId
        DispatchQueue.global().async { [weak self] in
            let result = ConversationAPI.getConversation(conversationId: conversationID)
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.navigationItem.rightBarButtonItem = nil
                let conversation = self.conversation
                if !conversation.isExpirationResolved || conversation.status != ConversationStatus.SUCCESS.rawValue {
                    if let local = ConversationDAO.shared.getConversation(conversationId: conversationID),
                       local.status == ConversationStatus.SUCCESS.rawValue
                    {
                        conversation.expireIn = local.expireIn
                        conversation.status = local.status
                    } else {
                        switch result {
                        case .success(let response):
                            conversation.expireIn = response.expireIn
                        case .failure(.notFound):
                            if !conversation.isExpirationResolved {
                                conversation.expireIn = Conversation.defaultExpirationDuration
                                conversation.status = ConversationStatus.START.rawValue
                            }
                        case .failure(let error):
                            if !conversation.isExpirationResolved {
                                showAutoHiddenHud(style: .error, text: error.localizedDescription)
                                return
                            }
                        }
                    }
                    conversation.isExpirationResolved = true
                    NotificationCenter.default.post(
                        name: MixinServices.conversationDidChangeNotification,
                        object: ConversationChange(conversationId: conversationID, action: .update(conversation: conversation)),
                    )
                }
                self.reloadExpirationOptions()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let headerView = tableView.tableHeaderView, tableView.bounds.width > 0 else {
            return
        }
        let sizeToFit = CGSize(width: tableView.bounds.width, height: UIView.layoutFittingExpandedSize.height)
        let headerSize = headerView.sizeThatFits(sizeToFit)
        guard headerView.frame.size != headerSize else {
            return
        }
        headerView.frame.size = headerSize
        tableView.tableHeaderView = headerView
    }
    
}

extension MessageExpirationDurationViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let isEnabled = canEdit && conversation.isExpirationResolved
        cell.isUserInteractionEnabled = isEnabled
        cell.contentView.alpha = isEnabled ? 1 : 0.5
        if isEnabled {
            cell.accessibilityTraits.remove(.notEnabled)
        } else {
            cell.accessibilityTraits.insert(.notEnabled)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard canEdit, conversation.isExpirationResolved else {
            return
        }
        let option = Option.allCases[indexPath.row]
        if let expireIn = option.expireIn {
            update(expireIn: expireIn)
        } else {
            let picker = CustomMessageExpirationDurationPickerViewController(
                expireIn: currentExpireIn,
                onPick: update(expireIn:),
            )
            present(picker, animated: true)
        }
    }
    
}

extension MessageExpirationDurationViewController {
    
    enum Option: CaseIterable {
        
        case off
        case oneDay
        case oneWeek
        case oneMonth
        case custom
        
        var expireIn: Int64? {
            switch self {
            case .off:
                0
            case .oneDay:
                Int64(TimeInterval.day)
            case .oneWeek:
                Int64(TimeInterval.week)
            case .oneMonth:
                Int64(TimeInterval.month)
            case .custom:
                nil
            }
        }
        
        var title: String {
            if let expireIn {
                ExpiredMessageDurationFormatter.string(from: expireIn)
            } else {
                R.string.localizable.custom_time()
            }
        }
        
        init(expireIn: Int64) {
            self = Self.allCases.first(where: { $0.expireIn == expireIn }) ?? .custom
        }
        
    }
    
    private func reloadExpirationOptions() {
        tableView.allowsSelection = canEdit && conversation.isExpirationResolved
        if conversation.isExpirationResolved {
            currentExpireIn = conversation.expireIn
            setAccessory(.checkmark, forRowWith: currentExpireIn)
        }
        tableView.reloadData()
    }
    
    private func setAccessory(_ accessory: SettingsRow.Accessory, forRowWith expireIn: Int64) {
        let option = Option(expireIn: expireIn)
        guard let index = Option.allCases.firstIndex(of: option) else {
            assertionFailure("No way an option not included in allCases")
            return
        }
        switch option {
        case .custom:
            rows[index].subtitle = .text(ExpiredMessageDurationFormatter.string(from: expireIn))
        default:
            if let index = Option.allCases.firstIndex(of: .custom) {
                rows[index].subtitle = nil
            }
        }
        section.setAccessory(accessory, forRowAt: index)
    }
    
    private func update(expireIn: Int64) {
        guard canEdit, conversation.isExpirationResolved, expireIn != currentExpireIn else {
            return
        }
        tableView.isUserInteractionEnabled = false
        setAccessory(.busy, forRowWith: expireIn)
        let conversationID = conversation.conversationId
        let completion: (MixinAPI.Result<Empty>) -> Void = { [weak self] result in
            switch result {
            case .success:
                ConversationDAO.shared.updateExpireIn(expireIn: expireIn, conversationId: conversationID)
                if let self {
                    self.conversation.expireIn = expireIn
                    self.currentExpireIn = expireIn
                }
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
            if let self {
                self.setAccessory(.checkmark, forRowWith: self.currentExpireIn)
                self.tableView.isUserInteractionEnabled = true
            }
        }
        let updateExpiration = {
            ConversationAPI.updateExpireIn(conversationID: conversationID, expireIn: expireIn, completion: completion)
        }
        if !conversation.isGroup(),
           ConversationDAO.shared.getConversationStatus(conversationId: conversationID) != ConversationStatus.SUCCESS.rawValue
        {
            let request = CreateConversationRequest(
                conversationID: conversationID,
                name: nil,
                category: ConversationCategory.CONTACT.rawValue,
                participants: [ParticipantRequest(userId: conversation.ownerId, role: "")],
                randomID: nil,
            )
            ConversationAPI.createConversation(conversation: request) { [weak self] result in
                switch result {
                case .success(let response):
                    ConversationDAO.shared.createConversation(conversation: response, targetStatus: .SUCCESS)
                    if let self {
                        self.conversation.status = ConversationStatus.SUCCESS.rawValue
                        self.conversation.expireIn = response.expireIn
                        self.currentExpireIn = response.expireIn
                    }
                    updateExpiration()
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            updateExpiration()
        }
    }
    
}
