import UIKit
import MixinServices

final class TransferInputAmountViewController: InputAmountViewController {
    
    override var token: any TransferableToken {
        tokenItem
    }
    
    private let tokenItem: TokenItem
    private let receiver: UserItem
    private let progress: UserInteractionProgress?
    private let traceID = UUID().uuidString.lowercased()
    
    private var note: String? {
        didSet {
            changeNoteButton.configuration?.attributedTitle = if let note {
                AttributedString(note, attributes: noteAttributes)
            } else {
                AttributedString(R.string.localizable.add_a_note(), attributes: addNoteAttributes)
            }
        }
    }
    
    private weak var changeNoteButton: UIButton!
    
    private var noteAttributes: AttributeContainer {
        var container = AttributeContainer()
        container.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        container.foregroundColor = R.color.text()
        return container
    }
    
    private var addNoteAttributes: AttributeContainer {
        var container = AttributeContainer()
        container.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        container.foregroundColor = R.color.text_tertiary()
        return container
    }
    
    init(tokenItem: TokenItem, receiver: UserItem, progress: UserInteractionProgress?) {
        self.tokenItem = tokenItem
        self.receiver = receiver
        self.progress = progress
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let progress {
            navigationItem.titleView = NavigationTitleView(
                title: R.string.localizable.send(),
                subtitle: progress.description
            )
        } else {
            title = R.string.localizable.send()
        }
        
        let noteStackView = {
            let titleLabel = InsetLabel()
            titleLabel.contentInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
            titleLabel.text = R.string.localizable.optional_note()
            titleLabel.textColor = R.color.text_tertiary()
            titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
            titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            
            var config: UIButton.Configuration = .plain()
            config.baseBackgroundColor = .clear
            config.imagePlacement = .trailing
            config.imagePadding = 14
            config.image = R.image.ic_accessory_disclosure()
            config.attributedTitle = AttributedString(R.string.localizable.add_a_note(), attributes: addNoteAttributes)
            let button = UIButton(configuration: config)
            button.tintColor = R.color.chat_pin_count_background()
            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            button.addTarget(self, action: #selector(changeNote(_:)), for: .touchUpInside)
            changeNoteButton = button
            
            let stackView = UIStackView(arrangedSubviews: [titleLabel, button])
            switch ScreenWidth.current {
            case .short:
                stackView.axis = .vertical
            case .medium, .long:
                stackView.axis = .horizontal
            }
            return stackView
        }()
        accessoryStackView.insertArrangedSubview(noteStackView, at: 0)
        noteStackView.snp.makeConstraints { make in
            make.width.equalTo(view.snp.width).offset(-56)
        }
        
        tokenIconView.setIcon(token: tokenItem)
        tokenNameLabel.text = tokenItem.name
        tokenBalanceLabel.text = tokenItem.localizedBalanceWithSymbol
    }
    
    override func review(_ sender: Any) {
        guard !reviewButton.isBusy else {
            return
        }
        reviewButton.isBusy = true
        
        let memo = note ?? ""
        let traceID = self.traceID
        let amountIntent = self.amountIntent
        
        let payment = Payment(
            traceID: traceID,
            token: tokenItem,
            tokenAmount: tokenAmount,
            fiatMoneyAmount: fiatMoneyAmount,
            memo: memo
        )
        let onPreconditonFailure = { (reason: PaymentPreconditionFailureReason) in
            self.reviewButton.isBusy = false
            switch reason {
            case .userCancelled, .loggedOut:
                break
            case .description(let message):
                showAutoHiddenHud(style: .error, text: message)
            }
        }
        
        payment.checkPreconditions(
            transferTo: .user(receiver),
            reference: nil,
            on: self,
            onFailure: onPreconditonFailure
        ) { (operation, issues) in
            self.reviewButton.isBusy = false
            let preview = TransferPreviewViewController(
                issues: issues,
                operation: operation,
                amountDisplay: amountIntent,
                redirection: nil
            )
            self.present(preview, animated: true)
        }
    }
    
    @objc private func changeNote(_ sender: UIButton) {
        if note == nil {
            presentNoteEditor()
        } else {
            let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: R.string.localizable.edit_note(), style: .default, handler: { _ in
                self.presentNoteEditor()
            }))
            sheet.addAction(UIAlertAction(title: R.string.localizable.delete_note(), style: .destructive, handler: { _ in
                self.note = nil
            }))
            sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
            present(sheet, animated: true)
        }
    }
    
    private func presentNoteEditor() {
        let input = UIAlertController(title: R.string.localizable.add_a_note(), message: nil, preferredStyle: .alert)
        input.addTextField { [note] textField in
            textField.text = note
        }
        input.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel))
        input.addAction(UIAlertAction(title: R.string.localizable.save(), style: .default, handler: { [unowned input] _ in
            guard let textField = input.textFields?.first else {
                return
            }
            if let note = textField.text, !note.isEmpty {
                self.note = note
            } else {
                self.note = nil
            }
        }))
        present(input, animated: true)
    }
    
}
