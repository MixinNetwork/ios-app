import UIKit
import SDWebImage
import MixinServices

final class TransferInputAmountViewController: TokenConsumingInputAmountViewController {
    
    var reference: String?
    var redirection: URL?
    
    private let traceID: String
    private let tokenItem: MixinTokenItem
    private let receiver: Payment.TransferDestination
    private let maxNoteDataCount = 200
    
    private var note: String {
        didSet {
            updateChangeNoteButton()
        }
    }
    
    private weak var noteStackView: UIStackView!
    private weak var changeNoteButton: UIButton!
    
    private var addTokenButton: UIButton?
    
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
    
    init(
        traceID: String = UUID().uuidString.lowercased(),
        tokenItem: MixinTokenItem,
        receiver: Payment.TransferDestination,
        note: String = ""
    ) {
        self.traceID = traceID
        self.tokenItem = tokenItem
        self.receiver = receiver
        self.note = note
        super.init(token: tokenItem, precision: MixinToken.internalPrecision)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = switch receiver {
        case let .user(user):
            UserNavigationTitleView(title: R.string.localizable.send_to_title(), user: user)
        case let .multisig(_, users):
            MultisigNavigationTitleView(users: users)
        case let .mainnet(_, address):
            NavigationTitleView(
                title: R.string.localizable.send_to_title(),
                subtitle: Address.compactRepresentation(of: address)
            )
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
            config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 5, bottom: 7, trailing: 12)
            config.imagePlacement = .trailing
            config.imagePadding = 14
            config.image = R.image.ic_accessory_disclosure()
            config.attributedTitle = AttributedString(R.string.localizable.add_a_note(), attributes: addNoteAttributes)
            let button = UIButton(configuration: config)
            button.tintColor = R.color.icon_tint_tertiary()
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
        self.noteStackView = noteStackView
        updateChangeNoteButton()
        
        tokenIconView.setIcon(token: tokenItem)
        tokenNameLabel.text = tokenItem.name
        tokenBalanceLabel.text = tokenItem.localizedBalanceWithSymbol
        
        reporter.report(event: .sendAmount)
    }
    
    override func review(_ sender: Any) {
        guard !reviewButton.isBusy else {
            return
        }
        reviewButton.isBusy = true
        
        let traceID = self.traceID
        let amountIntent = self.amountIntent
        
        let payment = Payment(
            traceID: traceID,
            token: tokenItem,
            tokenAmount: tokenAmount,
            fiatMoneyAmount: fiatMoneyAmount,
            memo: note
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
            transferTo: receiver,
            reference: reference,
            on: self,
            onFailure: onPreconditonFailure
        ) { [redirection] (operation, issues) in
            self.reviewButton.isBusy = false
            let preview = TransferPreviewViewController(
                issues: issues,
                operation: operation,
                amountDisplay: amountIntent,
                redirection: redirection
            )
            self.present(preview, animated: true)
        }
    }
    
    override func reloadViewsWithBalanceRequirements() {
        super.reloadViewsWithBalanceRequirements()
        if inputAmountRequirement.isSufficient {
            removeAddTokenButton()
        } else {
            addAddTokenButton()
        }
    }
    
    @objc func addToken(_ sender: Any) {
        let selector = AddTokenMethodSelectorViewController(token: tokenItem)
        selector.delegate = self
        present(selector, animated: true)
    }
    
    @objc private func changeNote(_ sender: UIButton) {
        if note.isEmpty {
            presentNoteEditor()
        } else {
            let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: R.string.localizable.edit_note(), style: .default, handler: { _ in
                self.presentNoteEditor()
            }))
            sheet.addAction(UIAlertAction(title: R.string.localizable.delete_note(), style: .destructive, handler: { _ in
                self.note = ""
            }))
            sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
            present(sheet, animated: true)
        }
    }
    
    private func addAddTokenButton() {
        if addTokenButton == nil {
            var config: UIButton.Configuration = .plain()
            config.baseBackgroundColor = .clear
            config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 5, bottom: 7, trailing: 5)
            let button = UIButton(configuration: config)
            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            button.addTarget(self, action: #selector(addToken(_:)), for: .touchUpInside)
            addTokenButton = button
        }
        if let addTokenButton {
            noteStackView.insertArrangedSubview(addTokenButton, at: 1)
            addTokenButton.configuration?.attributedTitle = AttributedString(
                R.string.localizable.add_token(token.symbol),
                attributes: addTokenAttributes
            )
        }
    }
    
    private func removeAddTokenButton() {
        addTokenButton?.removeFromSuperview()
    }
    
    private func updateChangeNoteButton() {
        changeNoteButton.configuration?.attributedTitle = if note.isEmpty {
            AttributedString(R.string.localizable.add_a_note(), attributes: addNoteAttributes)
        } else {
            AttributedString(note, attributes: noteAttributes)
        }
    }
    
    private func presentNoteEditor() {
        let input = UIAlertController(title: R.string.localizable.add_a_note(), message: nil, preferredStyle: .alert)
        input.addTextField { [note] textField in
            textField.text = note
            textField.delegate = self
        }
        input.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel))
        input.addAction(UIAlertAction(title: R.string.localizable.save(), style: .default, handler: { [unowned input] _ in
            guard let textField = input.textFields?.first else {
                return
            }
            if let note = textField.text, !note.isEmpty {
                self.note = note
            } else {
                self.note = ""
            }
        }))
        present(input, animated: true)
    }
    
}

extension TransferInputAmountViewController: UITextFieldDelegate {
    
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let text = (textField.text ?? "") as NSString
        let newText = text.replacingCharacters(in: range, with: string)
        return newText.utf8.count <= maxNoteDataCount
    }
    
}

extension TransferInputAmountViewController: AddTokenMethodSelectorViewController.Delegate {
    
    func addTokenMethodSelectorViewController(
        _ viewController: AddTokenMethodSelectorViewController,
        didPickMethod method: AddTokenMethodSelectorViewController.Method
    ) {
        let next = switch method {
        case .swap:
            MixinTradeViewController(
                mode: .simple,
                sendAssetID: nil,
                receiveAssetID: token.assetID,
                referral: nil
            )
        case .deposit:
            DepositViewController(token: tokenItem)
        }
        navigationController?.pushViewController(next, animated: true)
    }
    
}

extension TransferInputAmountViewController {
    
    private final class MultisigNavigationTitleView: UIStackView {
        
        init(users: [UserItem]) {
            assert(users.count > 1)
            super.init(frame: .zero)
            
            axis = .vertical
            distribution = .fill
            alignment = .center
            spacing = 2
            
            let titleLabel = UILabel()
            titleLabel.textColor = R.color.text()
            titleLabel.text = R.string.localizable.send_to_title()
            titleLabel.setFont(
                scaledFor: .systemFont(ofSize: 16, weight: .medium),
                adjustForContentSize: true
            )
            addArrangedSubview(titleLabel)
            
            let iconsStackView = UIStackView()
            let iconHeight: CGFloat = 18
            let iconFrame = CGRect(x: 0, y: 0, width: 18, height: 18)
            let maxIconCount = 4
            let visibleUserCount = users.count > maxIconCount ? maxIconCount - 1 : users.count
            for user in users.prefix(visibleUserCount) {
                let view = StackedIconWrapperView<AvatarImageView>(margin: 1, frame: iconFrame)
                view.backgroundColor = .clear
                view.iconView.titleFontSize = 9
                view.iconView.setImage(with: user)
                iconsStackView.addArrangedSubview(view)
            }
            let invisibleUserCount = users.count - visibleUserCount
            if invisibleUserCount > 0 {
                let view = StackedIconWrapperView<UILabel>(margin: 1, frame: iconFrame)
                view.backgroundColor = .clear
                let label = view.iconView
                label.backgroundColor = R.color.button_background_disabled()
                label.textColor = .white
                label.font = .systemFont(ofSize: 8)
                label.textAlignment = .center
                label.minimumScaleFactor = 0.1
                label.layer.cornerRadius = 8
                label.layer.masksToBounds = true
                label.text = "+\(invisibleUserCount)"
                iconsStackView.addArrangedSubview(view)
            }
            for (index, view) in iconsStackView.arrangedSubviews.enumerated() {
                let multiplier = index == iconsStackView.arrangedSubviews.count - 1 ? 1 : 0.5
                view.snp.makeConstraints { make in
                    make.width.equalTo(view.snp.height)
                        .multipliedBy(multiplier)
                }
            }
            addArrangedSubview(iconsStackView)
            iconsStackView.snp.makeConstraints { make in
                make.height.equalTo(iconHeight)
            }
        }
        
        required init(coder: NSCoder) {
            fatalError("Storyboard/Xib not supported")
        }
        
    }
    
}
