import UIKit
import MixinServices

class ChatTextSizeViewController: UIViewController {
        
    @IBOutlet weak var wallpaperImageView: WallpaperImageView!
    @IBOutlet weak var tableView: ConversationTableView!
    @IBOutlet weak var fontSizeSlider: FontSizeSlider!
    @IBOutlet weak var textSizeSwitch: UISwitch!
    
    private let chatFontSizeBefore = AppGroupUserDefaults.User.chatFontSize
    private let useSystemFontBefore = AppGroupUserDefaults.User.useSystemFont
    
    private var fontSizeDidChange: (() -> Void)?
    private var isConfirmed = false
    
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
        title = R.string.localizable.chat_text_size()
        navigationItem.rightBarButtonItem = .button(
            title: R.string.localizable.set(),
            target: self,
            action: #selector(setFontSize(_:))
        )
        view.backgroundColor = .white
        wallpaperImageView.wallpaper = .symbol
        textSizeSwitch.onTintColor = .theme
        textSizeSwitch.isOn = useSystemFontBefore
        fontSizeSlider.updateFontSize(chatFontSizeBefore)
        fontSizeSlider.updateUserInteraction(enabled: !useSystemFontBefore, animated: false)
        fontSizeSlider.addTarget(self, action: #selector(fontSizeChanged), for: .valueChanged)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !isConfirmed {
            AppGroupUserDefaults.User.chatFontSize = chatFontSizeBefore
            AppGroupUserDefaults.User.useSystemFont = useSystemFontBefore
        }
    }
    
    class func instance(fontSizeDidChange: @escaping (() -> Void)) -> UIViewController {
        let vc = R.storyboard.setting.chat_text_size()!
        vc.fontSizeDidChange = fontSizeDidChange
        return vc
    }
    
    @IBAction func switchAction(_ sender: Any) {
        let useSystemFont = textSizeSwitch.isOn
        AppGroupUserDefaults.User.useSystemFont = useSystemFont
        fontSizeSlider.updateUserInteraction(enabled: !useSystemFont, animated: true)
        tableView.reloadData()
    }
    
    @IBAction func fontSizeChanged(_ sender: FontSizeSlider) {
        AppGroupUserDefaults.User.chatFontSize = sender.fontSize
        tableView.reloadData()
    }
    
    @objc private func setFontSize(_ sender: Any) {
        isConfirmed = true
        fontSizeDidChange?()
        navigationController?.popViewController(animated: true)
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
