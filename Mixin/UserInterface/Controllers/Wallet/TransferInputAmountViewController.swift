import UIKit
import MixinServices

final class TransferInputAmountViewController: InputAmountViewController {
    
    override var token: any TransferableToken {
        tokenItem
    }
    
    private let tokenItem: TokenItem
    private let receiver: UserItem
    private let traceID = UUID().uuidString.lowercased()
    
    private var note: String? {
        didSet {
            changeNoteButton.configuration?.attributedTitle = if let note {
                AttributedString(note, attributes: noteAttributes)
            } else {
                AttributedString("Add a note", attributes: addNoteAttributes)
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
    
    init(tokenItem: TokenItem, receiver: UserItem) {
        self.tokenItem = tokenItem
        self.receiver = receiver
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.send()
        
        let noteStackView = {
            let titleLabel = InsetLabel()
            titleLabel.contentInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
            titleLabel.text = "Note (Optional)"
            titleLabel.textColor = R.color.text_tertiary()
            titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
            titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            
            var config: UIButton.Configuration = .plain()
            config.baseBackgroundColor = .clear
            config.imagePlacement = .trailing
            config.imagePadding = 14
            config.image = R.image.ic_accessory_disclosure()
            config.attributedTitle = AttributedString("Add a note", attributes: addNoteAttributes)
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
        
        tokenIconView.setIcon(token: tokenItem)
        tokenNameLabel.text = tokenItem.name
        tokenBalanceLabel.text = tokenItem.localizedBalanceWithSymbol
        inputMaxValueButton.isHidden = true
        
        addMultipliersView()
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
            sheet.addAction(UIAlertAction(title: "Edit Note", style: .default, handler: { _ in
                self.presentNoteEditor()
            }))
            sheet.addAction(UIAlertAction(title: "Delete Note", style: .destructive, handler: { _ in
                self.note = nil
            }))
            sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
            present(sheet, animated: true)
        }
    }
    
    private func presentNoteEditor() {
        let input = UIAlertController(title: "Add a note", message: nil, preferredStyle: .alert)
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
