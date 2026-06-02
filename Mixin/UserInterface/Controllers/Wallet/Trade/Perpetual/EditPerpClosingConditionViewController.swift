import UIKit
import SafariServices
import MixinServices

final class EditPerpClosingConditionViewController: UIViewController {
    
    enum OrderState {
        case draft
        case open(entryPrice: String)
    }
    
    private enum InputContent: Int, CaseIterable {
        case percentage
        case price
    }
    
    @IBOutlet weak var titleView: EditPerpsPositionTitleView!
    
    @IBOutlet weak var inputContentSelectorCollectionView: UICollectionView!
    @IBOutlet weak var inputContentSelectorLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var inputContentSelectorHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var inputSectionView: UIView!
    @IBOutlet weak var inputTitleLabel: UILabel!
    @IBOutlet weak var clearInputButton: UIButton!
    @IBOutlet weak var inputTextField: UITextField!
    @IBOutlet weak var inputTextFieldWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var fixedInputCollectionView: UICollectionView!
    @IBOutlet weak var fixedInputLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var fixedInputHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputDescriptionLabel: UILabel!
    
    @IBOutlet weak var inputErrorLabel: InsetLabel!
    
    @IBOutlet weak var introSectionView: UIView!
    @IBOutlet weak var introTitleLabel: UILabel!
    @IBOutlet weak var introDescriptionLabel: UILabel!
    @IBOutlet weak var introImageView: UIImageView!
    @IBOutlet weak var viewIntroButton: UIButton!
    
    @IBOutlet weak var actionsWrapperView: UIView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var confirmButton: UIButton!
    
    var onSet: ((Decimal?) -> ())?
    
    private let viewModel: PerpetualMarketViewModel
    private let side: PerpetualOrderSide
    private let margin: Decimal
    private let condition: PerpsAutoClosingCondition
    private let orderState: OrderState
    private let fixedInputs: [Decimal]
    private let previousAutoClosingPrice: Decimal?
    
    private var inputContent: InputContent {
        didSet {
            AppGroupUserDefaults.Wallet.perpsClosingConditionInputContent = inputContent.rawValue
        }
    }
    
    private var inputContentSelectorSizeObserver: NSKeyValueObservation?
    private var inputPrefixLabel: UILabel!
    private var inputSuffixLabel: UILabel!
    private var fixedInputSizeObserver: NSKeyValueObservation?
    
    private var userInputSimulationFormat = Decimal.FormatStyle.number
        .locale(.current)
        .grouping(.never)
        .sign(strategy: .never)
    
    init(
        viewModel: PerpetualMarketViewModel,
        side: PerpetualOrderSide,
        margin: Decimal,
        behavior: PerpsAutoClosingCondition.Behavior,
        leverage: Decimal,
        orderState: OrderState,
        liquidationPrice: Decimal,
        currentAutoClosingPrice: Decimal?,
    ) {
        self.viewModel = viewModel
        self.side = side
        self.margin = margin
        self.condition = PerpsAutoClosingCondition(
            behavior: behavior,
            basePrice: viewModel.decimalPrice,
            side: side,
            leverage: leverage,
            priceScale: viewModel.market.priceScale,
            liquidationPrice: liquidationPrice
        )
        self.orderState = orderState
        self.fixedInputs = switch behavior {
        case .takeProfit:
            [0.1, 0.25, 0.5, 1]
        case .stopLoss:
            [-0.05, -0.1, -0.25, -0.5]
        }
        self.previousAutoClosingPrice = currentAutoClosingPrice
        self.inputContent = InputContent(
            rawValue: AppGroupUserDefaults.Wallet.perpsClosingConditionInputContent
        ) ?? .percentage
        let nib = R.nib.editPerpClosingConditionView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presentationController?.delegate = self
        if let price = previousAutoClosingPrice {
            try? condition.setPrice(price)
        }
        
        titleView.iconView.setIcon(tokenIconURL: viewModel.iconURL)
        switch orderState {
        case .draft:
            let price = viewModel.price
            let text = NSMutableAttributedString(
                string: R.string.localizable.auto_close_subtitle_before_open(price),
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .caption1),
                    .foregroundColor: R.color.text_quaternary()!,
                ]
            )
            if let range = text.string.range(of: price, options: .backwards) {
                text.setAttributes(
                    [.foregroundColor: R.color.text_tertiary()!],
                    range: NSRange(range, in: text.string)
                )
            }
            titleView.subtitleLabel.attributedText = text
        case .open(let entryPrice):
            let currentPrice = viewModel.price
            let text = NSMutableAttributedString(
                string: R.string.localizable.auto_close_subtitle_after_open(
                    entryPrice,
                    currentPrice
                ),
                attributes: [.foregroundColor: R.color.text_quaternary()!]
            )
            if let range = text.string.range(of: entryPrice) {
                text.setAttributes(
                    [.foregroundColor: R.color.text_tertiary()!],
                    range: NSRange(range, in: text.string)
                )
            }
            if let range = text.string.range(of: currentPrice, options: .backwards) {
                text.setAttributes(
                    [.foregroundColor: R.color.text_tertiary()!],
                    range: NSRange(range, in: text.string)
                )
            }
            titleView.subtitleLabel.attributedText = text
        }
        titleView.closeButton.addTarget(
            self,
            action: #selector(close(_:)),
            for: .touchUpInside
        )
        
        inputSectionView.layer.cornerRadius = 8
        inputSectionView.layer.masksToBounds = true
        inputTitleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        clearInputButton.configuration?.attributedTitle = {
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 14, weight: .medium)
            )
            return AttributedString(
                R.string.localizable.clear(),
                attributes: attributes
            )
        }()
        clearInputButton.titleLabel?.adjustsFontForContentSizeCategory = true
        inputPrefixLabel = UILabel()
        inputPrefixLabel.font = inputTextField.font
        inputPrefixLabel.textColor = R.color.text()
        inputSuffixLabel = UILabel()
        inputSuffixLabel.font = inputTextField.font
        inputSuffixLabel.textColor = R.color.text()
        inputTextField.leftView = inputPrefixLabel
        inputTextField.rightView = inputSuffixLabel
        inputTextField.delegate = self
        inputTextField.becomeFirstResponder()
        inputContentSelectorLayout.itemSize = UICollectionViewFlowLayout.automaticSize
        inputContentSelectorCollectionView.register(R.nib.exploreSegmentCell)
        inputContentSelectorSizeObserver = inputContentSelectorCollectionView.observe(
            \.contentSize,
             options: [.new]
        ) { [weak self] (_, change) in
            guard let newValue = change.newValue, let self else {
                return
            }
            self.inputContentSelectorHeightConstraint.constant = newValue.height
            self.view.layoutIfNeeded()
        }
        inputContentSelectorCollectionView.dataSource = self
        inputContentSelectorCollectionView.delegate = self
        inputContentSelectorCollectionView.reloadData()
        if let item = InputContent.allCases.firstIndex(of: inputContent) {
            let indexPath = IndexPath(item: item, section: 0)
            inputContentSelectorCollectionView.selectItem(
                at: indexPath,
                animated: false,
                scrollPosition: []
            )
        }
        reloadInputSection(content: inputContent)
        fixedInputLayout.itemSize = UICollectionViewFlowLayout.automaticSize
        fixedInputCollectionView.register(R.nib.fixedInputCell)
        fixedInputSizeObserver = fixedInputCollectionView.observe(
            \.contentSize,
             options: [.new]
        ) { [weak self] (_, change) in
            guard let newValue = change.newValue, let self else {
                return
            }
            self.fixedInputHeightConstraint.constant = newValue.height
            self.view.layoutIfNeeded()
        }
        fixedInputCollectionView.dataSource = self
        fixedInputCollectionView.delegate = self
        fixedInputCollectionView.reloadData()
        inputDescriptionLabel.text = R.string.localizable.auto_close_description()
        
        inputErrorLabel.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        introSectionView.layer.cornerRadius = 8
        introSectionView.layer.masksToBounds = true
        introTitleLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        introDescriptionLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        viewIntroButton.configuration?.attributedTitle = {
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 14, weight: .medium)
            )
            return AttributedString(
                R.string.localizable.learn_more(),
                attributes: attributes
            )
        }()
        viewIntroButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        actionsWrapperView.snp.makeConstraints { make in
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
        }
        var actionButtonAttributes = AttributeContainer()
        actionButtonAttributes.font = UIFont.preferredFont(forTextStyle: .callout)
        cancelButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.cancel(),
            attributes: actionButtonAttributes
        )
        cancelButton.titleLabel?.adjustsFontForContentSizeCategory = true
        confirmButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.set(),
            attributes: actionButtonAttributes
        )
        confirmButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        switch condition.behavior {
        case .takeProfit:
            titleView.titleLabel.text = R.string.localizable.edit_auto_closing_title(
                R.string.localizable.take_profit(),
                side.localizedName,
                viewModel.market.tokenSymbol,
            )
            inputTitleLabel.text = R.string.localizable.take_profit_when()
            if BadgeManager.shared.hasViewed(identifier: .perpsTakeProfit) {
                introSectionView.isHidden = true
            } else {
                introSectionView.isHidden = false
                introTitleLabel.text = R.string.localizable.take_profit_intro_title()
                introDescriptionLabel.text = R.string.localizable.take_profit_intro_description()
                introImageView.image = R.image.take_profit_intro()
            }
        case .stopLoss:
            titleView.titleLabel.text = R.string.localizable.edit_auto_closing_title(
                R.string.localizable.stop_loss(),
                side.localizedName,
                viewModel.market.tokenSymbol,
            )
            inputTitleLabel.text = R.string.localizable.stop_loss_when()
            if BadgeManager.shared.hasViewed(identifier: .perpsStopLoss) {
                introSectionView.isHidden = true
            } else {
                introSectionView.isHidden = false
                introTitleLabel.text = R.string.localizable.stop_loss_intro_title()
                introDescriptionLabel.text = R.string.localizable.stop_loss_intro_description()
                introImageView.image = R.image.stop_loss_intro()
            }
        }
    }
    
    @IBAction func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @IBAction func clearInput(_ sender: Any) {
        inputTextField.text = nil
        inputEditingChanged(inputTextField)
    }
    
    @IBAction func inputEditingChanged(_ textField: UITextField) {
        if let input = textField.text, !input.isEmpty {
            textField.leftViewMode = .always
            textField.rightViewMode = .always
            var attributes: [NSAttributedString.Key: Any] = [:]
            if let font = textField.font {
                attributes[.font] = font
            }
            let width = (input as NSString).size(withAttributes: attributes).width
            + (textField.leftView?.intrinsicContentSize.width ?? 0)
            + (textField.rightView?.intrinsicContentSize.width ?? 0)
            inputTextFieldWidthConstraint.constant = ceil(width)
            let number = Decimal(string: input, locale: .current) ?? 0
            switch (inputContent, condition.behavior) {
            case (.percentage, .stopLoss):
                take(input: -number)
            default:
                take(input: number)
            }
            clearInputButton.isHidden = false
        } else {
            textField.leftViewMode = .never
            textField.rightViewMode = .never
            inputTextFieldWidthConstraint.constant = UIView.layoutFittingExpandedSize.width
            take(input: nil)
            clearInputButton.isHidden = true
        }
        inputSectionView.layoutIfNeeded()
    }
    
    @IBAction func dismissIntro(_ sender: Any) {
        switch condition.behavior {
        case .takeProfit:
            BadgeManager.shared.setHasViewed(identifier: .perpsTakeProfit)
        case .stopLoss:
            BadgeManager.shared.setHasViewed(identifier: .perpsStopLoss)
        }
        introSectionView.isHidden = true
    }
    
    @IBAction func viewIntro(_ sender: Any) {
        let url = switch condition.behavior {
        case .takeProfit:
            URL.perpsTakeProfit
        case .stopLoss:
            URL.perpsStopLoss
        }
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }
    
    @IBAction func confirmSetting(_ sender: Any) {
        if condition.price == 0 {
            onSet?(nil)
        } else {
            onSet?(condition.price)
        }
        presentingViewController?.dismiss(animated: true)
    }
    
    private func reloadInputSection(content: InputContent) {
        switch content {
        case .percentage:
            inputTextField.placeholder = switch condition.behavior {
            case .takeProfit:
                R.string.localizable.profit_reaches_percent()
            case .stopLoss:
                R.string.localizable.loss_reaches_percent()
            }
            switch SignPosition.percentage {
            case .left:
                switch condition.behavior {
                case .takeProfit:
                    inputPrefixLabel.text = "+%"
                case .stopLoss:
                    inputPrefixLabel.text = "-%"
                }
                inputSuffixLabel.text = nil
            case .right:
                switch condition.behavior {
                case .takeProfit:
                    inputPrefixLabel.text = "+"
                case .stopLoss:
                    inputPrefixLabel.text = "-"
                }
                inputSuffixLabel.text = "%"
            }
            if condition.percentage == 0 {
                inputTextField.text = nil
            } else {
                inputTextField.text = (condition.percentage * 100)
                    .formatted(userInputSimulationFormat)
            }
        case .price:
            inputTextField.placeholder = R.string.localizable.price_reaches_dollar()
            switch SignPosition.currency {
            case .left:
                inputPrefixLabel.text = "$"
                inputSuffixLabel.text = nil
            case .right:
                inputPrefixLabel.text = nil
                inputSuffixLabel.text = "$"
            }
            if condition.price == 0 {
                inputTextField.text = nil
            } else {
                inputTextField.text = condition.price
                    .formatted(userInputSimulationFormat)
            }
        }
        inputEditingChanged(inputTextField)
    }
    
    private func take(input: Decimal?) {
        guard let input else {
            inputDescriptionLabel.text = R.string.localizable.auto_close_description()
            inputErrorLabel.isHidden = true
            confirmButton.isEnabled = previousAutoClosingPrice != nil
            do {
                try condition.setPrice(0)
            } catch {
                assertionFailure()
            }
            return
        }
        guard input != 0 else {
            inputDescriptionLabel.text = R.string.localizable.auto_close_description()
            inputErrorLabel.isHidden = true
            confirmButton.isEnabled = false
            do {
                try condition.setPrice(0)
            } catch {
                assertionFailure()
            }
            return
        }
        do {
            switch inputContent {
            case .percentage:
                try condition.setPercentage(input / 100)
            case .price:
                try condition.setPrice(input)
            }
            if margin == 0 {
                inputDescriptionLabel.text = R.string.localizable.auto_close_description()
            } else {
                let maxChange = condition.maxChange(margin: margin)
                switch condition.behavior {
                case .takeProfit:
                    let description = NSMutableAttributedString(
                        string: R.string.localizable.max_profit(maxChange),
                        attributes: [.foregroundColor: R.color.text_quaternary()!]
                    )
                    if let range = description.string.range(of: maxChange, options: .backwards) {
                        description.setAttributes(
                            [.foregroundColor: MarketColor.rising.uiColor],
                            range: NSRange(range, in: description.string)
                        )
                    }
                    inputDescriptionLabel.attributedText = description
                case .stopLoss:
                    let description = NSMutableAttributedString(
                        string: R.string.localizable.max_loss(maxChange),
                        attributes: [.foregroundColor: R.color.text_quaternary()!]
                    )
                    if let range = description.string.range(of: maxChange, options: .backwards) {
                        description.setAttributes(
                            [.foregroundColor: MarketColor.falling.uiColor],
                            range: NSRange(range, in: description.string)
                        )
                    }
                    inputDescriptionLabel.attributedText = description
                }
            }
            inputErrorLabel.isHidden = true
            confirmButton.isEnabled = condition.price > 0
        } catch {
            inputDescriptionLabel.text = R.string.localizable.auto_close_description()
            inputErrorLabel.text = switch error {
            case let .mustHigherThan(lowest):
                R.string.localizable.the_price_must_higher_than(
                    lowest.formatted(viewModel.userDisplayPriceFormatStyle)
                )
            case let .mustLowerThan(highest):
                R.string.localizable.the_price_must_lower_than(
                    highest.formatted(viewModel.userDisplayPriceFormatStyle)
                )
            }
            inputErrorLabel.isHidden = false
            confirmButton.isEnabled = false
        }
    }
    
}

extension EditPerpClosingConditionViewController: UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        false
    }
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        
    }
    
}

extension EditPerpClosingConditionViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch collectionView {
        case inputContentSelectorCollectionView:
            InputContent.allCases.count
        case fixedInputCollectionView:
            fixedInputs.count
        default:
            0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch collectionView {
        case inputContentSelectorCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
            switch InputContent(rawValue: indexPath.item)! {
            case .percentage:
                cell.label.text = R.string.localizable.pnl()
            case .price:
                cell.label.text = R.string.localizable.price()
            }
            return cell
        case fixedInputCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.fixed_input, for: indexPath)!
            let value = fixedInputs[indexPath.item]
            cell.label.text = PercentageFormatter.string(
                from: value,
                format: .precision,
                sign: .always
            )
            return cell
        default:
            return UICollectionViewCell()
        }
    }
    
}

extension EditPerpClosingConditionViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        false
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch collectionView {
        case inputContentSelectorCollectionView:
            inputContent = InputContent(rawValue: indexPath.item)!
            reloadInputSection(content: inputContent)
        case fixedInputCollectionView:
            collectionView.deselectItem(at: indexPath, animated: true)
            let percentage = fixedInputs[indexPath.item]
            switch inputContent {
            case .percentage:
                inputTextField.text = (percentage * 100).formatted(userInputSimulationFormat)
                inputEditingChanged(inputTextField)
            case .price:
                inputContent = .percentage
                inputTextField.text = (percentage * 100).formatted(userInputSimulationFormat)
                inputEditingChanged(inputTextField)
                inputContent = .price
                reloadInputSection(content: inputContent)
            }
        default:
            break
        }
    }
    
}

extension EditPerpClosingConditionViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newText = ((textField.text ?? "") as NSString)
            .replacingCharacters(in: range, with: string)
        if newText.isEmpty || inputContent == .percentage {
            return true
        } else if let value = Decimal(string: newText, locale: .current) {
            return value.numberOfSignificantFractionalDigits <= viewModel.market.priceScale
        } else {
            return false
        }
    }
    
}
