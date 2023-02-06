import UIKit
import MixinServices

class ChatTextSizeViewController: UIViewController {
        
    @IBOutlet weak var wallpaperImageView: WallpaperImageView!
    @IBOutlet weak var tableView: ConversationTableView!
    @IBOutlet weak var fontSizeSlider: FontSizeSlider!
    @IBOutlet weak var textSizeSwitch: UISwitch!
    
    private var fontSizeDidChange: (() -> Void)?
    private var isSetted = false
    private let defaultFontSize = AppGroupUserDefaults.User.chatFontSize
    private let defaultUseSystemFont = AppGroupUserDefaults.User.useSystemFont
    
    private var mockViewModels: [String: [MessageViewModel]] {
        let contents = [
            (userId: myUserId, content: R.string.localizable.how_are_you()),
            (userId: "2", content: R.string.localizable.i_am_good())
        ]
        let messages = contents.map { (userId, content) in
            MessageItem(messageId: UUID().uuidString,
                        conversationId: UUID().uuidString,
                        userId: userId,
                        category: MessageCategory.PLAIN_TEXT.rawValue,
                        content: content,
                        status: MessageStatus.DELIVERED.rawValue,
                        createdAt: Date().toUTCString())
        }
        let factory = MessageViewModelFactory()
        return factory.viewModels(with: messages, fits: UIScreen.main.bounds.width).viewModels
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        wallpaperImageView.wallpaper = .symbol
        textSizeSwitch.onTintColor = .theme
        textSizeSwitch.isOn = defaultUseSystemFont
        fontSizeSlider.delegate = self
        fontSizeSlider.textSize = defaultFontSize
        fontSizeSlider.updateUserInteraction(enabled: !defaultUseSystemFont, animated: false)
        container?.titleLabel.font = .systemFont(ofSize: 16)
        container?.rightButton.titleLabel?.font = .systemFont(ofSize: 16)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !isSetted {
            AppGroupUserDefaults.User.chatFontSize = defaultFontSize
            AppGroupUserDefaults.User.useSystemFont = defaultUseSystemFont
        }
    }
    
    class func instance(fontSizeDidChange: @escaping (() -> Void)) -> UIViewController {
        let vc = R.storyboard.setting.chat_text_size()!
        vc.fontSizeDidChange = fontSizeDidChange
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.chat_text_size())
    }
    
    @IBAction func switchAction(_ sender: Any) {
        let useSystemFont = textSizeSwitch.isOn
        AppGroupUserDefaults.User.useSystemFont = useSystemFont
        fontSizeSlider.updateUserInteraction(enabled: !useSystemFont, animated: true)
        tableView.reloadData()
    }
    
}

extension ChatTextSizeViewController: FontSizeSliderDelegate {
    
    func fontSizeSlider(_ slider: FontSizeSlider, didChangeFontSize size: ChatFontSize) {
        AppGroupUserDefaults.User.chatFontSize = size
        tableView.reloadData()
    }
    
}

extension ChatTextSizeViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        isSetted = true
        fontSizeDidChange?()
        navigationController?.popViewController(animated: true)
    }
    
    func textBarRightButton() -> String? {
        R.string.localizable.set()
    }
    
    func prepareBar(rightButton: StateResponsiveButton) {
        rightButton.setTitleColor(.systemTint, for: .normal)
        rightButton.isEnabled = true
    }
    
}

extension ChatTextSizeViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let models = mockViewModels.first?.value {
            return models.count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel(at: indexPath.row) else {
            return self.tableView.dequeueReusableCell(withReuseId: .unknown, for: indexPath)
        }
        let cell = self.tableView.dequeueReusableCell(withMessage: viewModel.message, for: indexPath)
        if let cell = cell as? MessageCell {
            CATransaction.performWithoutAnimation {
                cell.render(viewModel: viewModel)
                cell.layoutIfNeeded()
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if let model = viewModel(at: indexPath.row) {
            return model.cellHeight
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        ConversationDateHeaderView.height
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ConversationTableView.ReuseId.header.rawValue) as! ConversationDateHeaderView
        if let date = mockViewModels.keys.first {
            header.label.text = DateFormatter.yyyymmdd.date(from: date)?.chatTimeAgo()
        }
        return header
    }
    
}

extension ChatTextSizeViewController {
    
    private func viewModel(at index: Int) -> MessageViewModel? {
        if let models = mockViewModels.first?.value, index < models.count {
            return models[index]
        } else {
            return nil
        }
    }
    
}
