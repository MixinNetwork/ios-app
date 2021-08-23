import UIKit
import MixinServices

class PinMessagesPreviewViewController: StaticMessagesViewController {

    private let conversationId: String
    private let bottomBarViewHeight: CGFloat = 50
    
    private var pinnedMessageItems: [MessageItem] = []
    
    private lazy var bottomBarView: UIView = {
        let button = UIButton()
        button.setTitle(R.string.localizable.chat_unpin_all_messages(), for: .normal)
        button.setTitleColor(R.color.theme(), for: .normal)
        button.addTarget(self, action: #selector(unpinAllAction), for: .touchUpInside)
        let view = UIView()
        view.backgroundColor = R.color.background()
        view.addSubview(button)
        button.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(bottomBarViewHeight)
        }
        return view
    }()
    
    init(conversationId: String) {
        self.conversationId = conversationId
        super.init(audioManager: PinAudioMessagePlayingManager())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let layoutWidth = AppDelegate.current.mainWindow.bounds.width
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.pinnedMessageItems = PinMessageDAO.shared.messageItems(conversationId: self.conversationId)
            let (dates, viewModels) = self.categorizedViewModels(with: self.pinnedMessageItems, fits: layoutWidth)
            let isAdmin = ParticipantDAO.shared.isAdmin(conversationId: self.conversationId, userId: myUserId)
            DispatchQueue.main.async {
                if isAdmin {
                    let safeAreaInsets = AppDelegate.current.mainWindow.safeAreaInsets
                    self.view.addSubview(self.bottomBarView)
                    self.bottomBarView.snp.makeConstraints { make in
                        make.left.right.equalToSuperview()
                        make.height.equalTo(safeAreaInsets.bottom + self.bottomBarViewHeight)
                        make.bottom.equalTo(-safeAreaInsets.top)
                    }
                    self.tableView.contentInset.bottom = self.tableView.contentInset.bottom + self.bottomBarViewHeight
                }
                self.titleLabel.text = R.string.localizable.chat_pinned_messages_count(viewModels.count)
                self.dates = dates
                self.viewModels = viewModels
                self.tableView.reloadData()
            }
        }
    }
    
}

extension PinMessagesPreviewViewController {
    
    @objc private func unpinAllAction() {
        let controller = UIAlertController(title: R.string.localizable.chat_alert_unpin_all_messages(), message: nil, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil)
        let unpinAction = UIAlertAction(title: R.string.localizable.menu_unpin(), style: .default) { _ in
            self.queue.async { [weak self] in
                guard let self = self else {
                    return
                }
                self.pinnedMessageItems.forEach({ PinMessageDAO.shared.unpinMessage(fullMessage: $0) })
                DispatchQueue.main.async {
                    self.dismissAsChild(completion: nil)
                }
            }
        }
        controller.addAction(cancelAction)
        controller.addAction(unpinAction)
        present(controller, animated: true, completion: nil)
    }
    
}
