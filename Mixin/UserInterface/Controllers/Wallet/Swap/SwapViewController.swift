import UIKit
import OrderedCollections
import MixinServices

class SwapViewController: UIViewController {
    
    enum Mode: Int, CaseIterable {
        case simple
        case advanced
    }
    
    enum Section: Int, CaseIterable {
        case modeSelector
        case amountInput
        case priceInput
        case simpleModePrice
        case openOrders
        case expiry
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var reviewButtonWrapperView: UIView!
    @IBOutlet weak var reviewButton: RoundedButton!
    
    var advanceModeAvailable: Bool {
        false
    }
    
    var mode: Mode {
        didSet {
            switch mode {
            case .simple:
                break
            case .advanced:
                requester?.stop()
                requester = nil
            }
            reloadSections(mode: mode, price: price)
        }
    }
    
    var sendToken: BalancedSwapToken? {
        didSet {
            if let sendToken {
                sendViewStyle = .token(sendToken)
            } else {
                sendViewStyle = .selectable
            }
        }
    }
    
    var receiveToken: BalancedSwapToken? {
        didSet {
            if let receiveToken {
                receiveViewStyle = .token(receiveToken)
            } else {
                receiveViewStyle = .selectable
            }
        }
    }
    
    // Key is asset id
    private(set) var swappableTokens: OrderedDictionary<String, BalancedSwapToken> = [:]
    private(set) var quote: SwapQuote?
    
    private let arbitrarySendAssetID: String?
    private let arbitraryReceiveAssetID: String?
    private let tokenSource: RouteTokenSource
    
    private weak var showReviewButtonConstraint: NSLayoutConstraint!
    private weak var hideReviewButtonConstraint: NSLayoutConstraint!
    
    private lazy var userInputSimulationFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.roundingMode = .floor
        formatter.maximumFractionDigits = 8
        formatter.usesGroupingSeparator = false
        return formatter
    }()
    
    private var sections: [Section] = []
    private var contentSizeObservation: NSKeyValueObservation?
    private var requester: SwapQuotePeriodicRequester?
    private var amountRange: SwapQuotePeriodicRequester.AmountRange?
    private var priceUnit: SwapQuote.PriceUnit = .send
    private var openOrders: [LimitOrder] = []
    
    // SwapAmountInputCell
    private weak var swapAmountInputCell: SwapAmountInputCell?
    
    private var sendAmountTextField: UITextField? {
        swapAmountInputCell?.sendAmountTextField
    }
    
    private var receiveAmountTextField: UITextField? {
        swapAmountInputCell?.receiveAmountTextField
    }
    
    private var sendViewStyle: SwapAmountInputCell.TokenSelectorStyle = .loading {
        didSet {
            swapAmountInputCell?.updateSendView(style: sendViewStyle)
        }
    }
    
    private var receiveViewStyle: SwapAmountInputCell.TokenSelectorStyle = .loading {
        didSet {
            swapAmountInputCell?.updateReceiveView(style: receiveViewStyle)
        }
    }
    
    // SwapPriceCell
    private weak var swapPriceCell: SwapPriceCell?
    
    private var swapPriceContent: SwapPriceCell.Content? = nil {
        didSet {
            swapPriceCell?.setContent(swapPriceContent)
        }
    }
    
    private var swapPriceProgress: Double = 0
    
    // SwapPriceInputCell
    private weak var priceInputCell: SwapPriceInputCell?
    
    private var price: Decimal = 0 {
        didSet {
            reloadSections(mode: mode, price: price)
        }
    }
    
    // SwapExpirySelectorCell
    private var selectedExpiry: LimitOrder.Expiry = .never
    
    init(
        mode: Mode,
        tokenSource: RouteTokenSource,
        sendAssetID: String?,
        receiveAssetID: String?
    ) {
        self.mode = mode
        self.arbitrarySendAssetID = sendAssetID
        self.arbitraryReceiveAssetID = receiveAssetID
        self.tokenSource = tokenSource
        let nib = R.nib.swapView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        showReviewButtonConstraint = reviewButtonWrapperView.bottomAnchor.constraint(
            equalTo: view.keyboardLayoutGuide.topAnchor
        )
        showReviewButtonConstraint.priority = .almostRequired
        hideReviewButtonConstraint = reviewButtonWrapperView.topAnchor.constraint(
            equalTo: view.keyboardLayoutGuide.topAnchor
        )
        hideReviewButtonConstraint.priority = .almostInexist
        NSLayoutConstraint.activate([showReviewButtonConstraint, hideReviewButtonConstraint])
        
        collectionView.register(
            R.nib.swapOpenOrderHeaderView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        collectionView.register(R.nib.exploreSegmentCell)
        collectionView.register(R.nib.swapAmountInputCell)
        collectionView.register(R.nib.swapPriceInputCell)
        collectionView.register(R.nib.swapPriceCell)
        collectionView.register(R.nib.swapNoOpenOrderCell)
        collectionView.register(R.nib.swapOpenOrderCell)
        collectionView.register(R.nib.swapExpirySelectorCell)
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, _) in
            switch self?.sections[sectionIndex] {
            case .modeSelector, .none:
                let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(100), heightDimension: .absolute(38))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .vertical(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 15, bottom: 16, trailing: 15)
                section.orthogonalScrollingBehavior = .continuous
                return section
            case .amountInput:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(252))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                return section
            case .priceInput:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(119))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 20, bottom: 8, trailing: 20)
                return section
            case .simpleModePrice:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(36))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
                return section
            case .openOrders:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = if let orders = self?.openOrders, !orders.isEmpty {
                    NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(1))
                } else {
                    NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(211))
                }
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                section.boundarySupplementaryItems = [
                    NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(57)),
                        elementKind: UICollectionView.elementKindSectionHeader,
                        alignment: .top
                    )
                ]
                return section
            case .expiry:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(49))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                return section
            }
        }
        contentSizeObservation = collectionView.observe(\.contentSize) { [weak self] (collectionView, _) in
            guard let self else {
                return
            }
            let reviewButtonFrame = self.reviewButton.convert(self.reviewButton.bounds, to: self.view)
            let contentViewFrame = collectionView.convert(collectionView.bounds, to: self.view)
            collectionView.alwaysBounceVertical = reviewButtonFrame.intersects(contentViewFrame)
        }
        collectionView.dataSource = self
        collectionView.delegate = self
        reloadSections(mode: mode, price: price)
        
        reloadTokens()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requester?.start(delay: 0)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        requester?.stop()
    }
    
    @IBAction func review(_ sender: RoundedButton) {
        
    }
    
    @objc func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "trade_home"])
    }
    
    @objc func sendAmountEditingChanged(_ sender: Any) {
        amountRange = nil
        scheduleNewRequesterIfAvailable()
    }
    
    @objc func changeSendToken(_ sender: Any) {
        
    }
    
    @objc func depositSendToken(_ sender: Any) {
        
    }
    
    @objc func inputSendTokenBalance(_ sender: Any) {
        inputSendAmount(multiplier: 1)
    }
    
    @objc func changeReceiveToken(_ sender: Any) {
        
    }
    
    @objc func swapPrice(_ sender: Any) {
        priceUnit = switch priceUnit {
        case .send:
                .receive
        case .receive:
                .send
        }
        if let quote {
            updateCurrentPriceRepresentation(quote: quote)
        }
    }
    
    @objc func swapSendingReceiving(_ sender: Any) {
        if let sender = sender as? UIButton, sender == swapAmountInputCell?.swapButton {
            let animation = CABasicAnimation(keyPath: "transform.rotation")
            animation.fromValue = 0
            animation.toValue = CGFloat.pi
            animation.duration = 0.35
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            sender.layer.add(animation, forKey: nil)
        }
        swap(&sendToken, &receiveToken)
        scheduleNewRequesterIfAvailable()
        saveTokenIDs()
    }
    
    @objc func priceEditingChanged(_ sender: UITextField) {
        self.price = if let text = sender.text {
            Decimal(string: text, locale: .current) ?? 0
        } else {
            0
        }
        
    }
    
    func prepareForReuse(sender: Any) {
//        sendAmountTextField.text = nil
//        sendAmountTextField.sendActions(for: .editingChanged)
//        reloadTokens() // Update send token balance
    }
    
    func reloadSections(mode: Mode, price: Decimal) {
        var sections: [Section] = switch mode {
        case .simple:
            [.modeSelector, .amountInput, .simpleModePrice]
        case .advanced:
            if price == 0 {
                [.modeSelector, .amountInput, .priceInput, .openOrders]
            } else {
                [.modeSelector, .amountInput, .priceInput, .expiry]
            }
        }
        if !advanceModeAvailable {
            sections.removeFirst()
        }
        if sections != self.sections {
            let switchingBetweenModes = sections.count != self.sections.count
            self.sections = sections
            if switchingBetweenModes {
                collectionView.reloadData()
                if let section = sections.firstIndex(of: .modeSelector) {
                    let indexPath = IndexPath(item: mode.rawValue, section: section)
                    collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                }
            } else {
                let sections = IndexSet(integer: sections.count - 1)
                collectionView.reloadSections(sections)
            }
            if sections.contains(.openOrders) {
                showReviewButtonConstraint.priority = .almostInexist
                hideReviewButtonConstraint.priority = .almostRequired
                reviewButtonWrapperView.alpha = 0
            } else {
                showReviewButtonConstraint.priority = .almostRequired
                hideReviewButtonConstraint.priority = .almostInexist
                reviewButtonWrapperView.alpha = 1
            }
            view.layoutSubviews()
        }
    }
    
    func balancedSwapToken(assetID: String) -> BalancedSwapToken? {
        nil
    }
    
    func balancedSwapTokens(
        from swappableTokens: [SwapToken]
    ) -> OrderedDictionary<String, BalancedSwapToken> {
        [:]
    }
    
    func handleInputChange() {
        switch mode {
        case .simple:
            scheduleNewRequesterIfAvailable()
        case .advanced:
            break
        }
    }
    
    func scheduleNewRequesterIfAvailable() {
        receiveAmountTextField?.text = nil
        quote = nil
        reviewButton.isEnabled = false
        requester?.stop()
        requester = nil
        guard
            let text = sendAmountTextField?.text,
            let sendAmount = Decimal(string: text, locale: .current),
            sendAmount > 0,
            let sendToken,
            let receiveToken
        else {
            swapPriceContent = nil
            reviewButton.setTitle(R.string.localizable.review(), for: .normal)
            return
        }
        if sendAmount > sendToken.decimalBalance {
            reviewButton.setTitle(R.string.localizable.insufficient_balance(), for: .normal)
        } else {
            reviewButton.setTitle(R.string.localizable.review(), for: .normal)
        }
        swapPriceContent = .calculating
        let requester = SwapQuotePeriodicRequester(
            sendToken: sendToken,
            sendAmount: sendAmount,
            receiveToken: receiveToken,
            slippage: 0.01,
            source: tokenSource
        )
        requester.delegate = self
        self.requester = requester
        requester.start(delay: 1)
    }
    
}

extension SwapViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension SwapViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sections[section] {
        case .modeSelector:
            Mode.allCases.count
        case .openOrders:
            max(1, openOrders.count)
        default:
            1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch sections[indexPath.section] {
        case .modeSelector:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
            let mode = Mode(rawValue: indexPath.item)!
            cell.label.text = switch mode {
            case .simple:
                R.string.localizable.swap_simple()
            case .advanced:
                R.string.localizable.swap_advanced()
            }
            return cell
        case .amountInput:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.swap_amount_input, for: indexPath)!
            if swapAmountInputCell != cell {
                let inputAccessoryView = SwapInputAccessoryView(
                    frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44)
                )
                inputAccessoryView.items = [
                    .init(title: "25%") { [weak self] in
                        self?.inputSendAmount(multiplier: 0.25)
                    },
                    .init(title: "50%") { [weak self] in
                        self?.inputSendAmount(multiplier: 0.5)
                    },
                    .init(title: R.string.localizable.max()) { [weak self] in
                        self?.inputSendAmount(multiplier: 1)
                    },
                ]
                inputAccessoryView.onDone = { [weak textField=cell.sendAmountTextField] in
                    textField?.resignFirstResponder()
                }
                cell.sendAmountTextField.inputAccessoryView = inputAccessoryView
                cell.sendAmountTextField.addTarget(
                    self,
                    action: #selector(sendAmountEditingChanged(_:)),
                    for: .editingChanged
                )
                cell.sendAmountTextField.delegate = self
                cell.sendTokenButton.addTarget(
                    self,
                    action: #selector(changeSendToken(_:)),
                    for: .touchUpInside
                )
                cell.depositSendTokenButton.addTarget(
                    self,
                    action: #selector(depositSendToken(_:)),
                    for: .touchUpInside
                )
                cell.sendBalanceButton.addTarget(
                    self,
                    action: #selector(inputSendTokenBalance(_:)),
                    for: .touchUpInside
                )
                cell.receiveTokenButton.addTarget(
                    self,
                    action: #selector(changeReceiveToken(_:)),
                    for: .touchUpInside
                )
                cell.swapButton.addTarget(
                    self,
                    action: #selector(swapSendingReceiving(_:)),
                    for: .touchUpInside
                )
                cell.sendAmountTextField.becomeFirstResponder()
                swapAmountInputCell = cell
            }
            cell.updateSendView(style: sendViewStyle)
            cell.updateReceiveView(style: receiveViewStyle)
            return cell
        case .priceInput:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.swap_price_input, for: indexPath)!
            cell.textField.text = if price.isZero {
                nil
            } else {
                "\(price)"
            }
            let token = switch priceUnit {
            case .send:
                sendToken
            case .receive:
                receiveToken
            }
            if let token {
                cell.networkLabel.text = token.chainName
                cell.tokenIconView.setIcon(swappableToken: token)
                cell.symbolLabel.text = token.symbol
                cell.tokenNameLabel.text = token.name
            }
            if priceInputCell != cell {
                let inputAccessoryView = SwapInputAccessoryView(
                    frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44)
                )
                inputAccessoryView.items = [
                    .init(title: R.string.localizable.current_market_price()) { [weak self] in
                        
                    },
                    .init(title: "-10%") { [weak self] in

                    },
                    .init(title: "-20%") { [weak self] in

                    },
                ]
                inputAccessoryView.onDone = { [weak textField=cell.textField] in
                    textField?.resignFirstResponder()
                }
                cell.textField.inputAccessoryView = inputAccessoryView
                cell.textField.addTarget(
                    self,
                    action: #selector(priceEditingChanged(_:)),
                    for: .editingChanged
                )
                priceInputCell = cell
            }
            return cell
        case .simpleModePrice:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.swap_price, for: indexPath)!
            if swapPriceCell != cell {
                cell.footerInfoButton.addTarget(
                    self,
                    action: #selector(inputAmountByRange(_:)),
                    for: .touchUpInside
                )
                cell.swapPriceButton.addTarget(
                    self,
                    action: #selector(swapPrice(_:)),
                    for: .touchUpInside
                )
                swapPriceCell = cell
            }
            cell.footerInfoProgressView.setProgress(swapPriceProgress, animationDuration: nil)
            return cell
        case .openOrders:
            if openOrders.isEmpty {
                return collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.swap_no_open_order, for: indexPath)!
            } else {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.swap_open_order, for: indexPath)!
                return cell
            }
        case .expiry:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.swap_expiry_selector, for: indexPath)!
            cell.selectedExpiry = selectedExpiry
            cell.onChange = { [weak self] expiry in
                self?.selectedExpiry = expiry
            }
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: R.reuseIdentifier.swap_open_order_header, for: indexPath)!
        view.label.text = R.string.localizable.open_orders_count(openOrders.count)
        return view
    }
    
}

extension SwapViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        sections[indexPath.section] == .modeSelector
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        false
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .modeSelector:
            mode = Mode(rawValue: indexPath.item)!
        default:
            break
        }
    }
    
}

extension SwapViewController: UITextFieldDelegate {
    
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let newText = ((textField.text ?? "") as NSString)
            .replacingCharacters(in: range, with: string)
        if newText.isEmpty {
            return true
        }
        let components = newText.components(separatedBy: currentDecimalSeparator)
        switch components.count {
        case 1:
            return true
        case 2:
            return components[1].count <= 8
        default:
            return false
        }
    }
    
}

extension SwapViewController: SwapQuotePeriodicRequesterDelegate {
    
    func swapQuotePeriodicRequesterWillUpdate(_ requester: SwapQuotePeriodicRequester) {
        swapPriceContent = .calculating
        reviewButton.isEnabled = false
    }
    
    func swapQuotePeriodicRequester(_ requester: SwapQuotePeriodicRequester, didUpdate result: Result<SwapQuote, any Error>) {
        switch result {
        case .success(let quote):
            self.quote = quote
            self.amountRange = nil
            Logger.general.debug(category: "Swap", message: "Got quote: \(quote)")
            swapAmountInputCell?.receiveAmountTextField.text = CurrencyFormatter.localizedString(
                from: quote.receiveAmount,
                format: .precision,
                sign: .never
            )
            updateCurrentPriceRepresentation(quote: quote)
            swapPriceProgress = 1
            swapPriceCell?.footerInfoProgressView.setProgress(1, animationDuration: nil)
            reviewButton.isEnabled = quote.sendAmount > 0
            && quote.sendAmount <= quote.sendToken.decimalBalance
            reporter.report(event: .tradeQuote, tags: ["type": "swap", "result": "success"])
        case .failure(let error):
            let description: String
            let amountRange: SwapQuotePeriodicRequester.AmountRange?
            let reason: String
            switch error {
            case let SwapQuotePeriodicRequester.ResponseError.invalidAmount(range):
                description = range.description
                amountRange = range
                reason = "invalid_amount"
            case MixinAPIResponseError.invalidQuoteAmount:
                description = R.string.localizable.swap_invalid_amount()
                amountRange = nil
                reason = "invalid_amount"
            case MixinAPIResponseError.noAvailableQuote:
                description = R.string.localizable.swap_no_available_quote()
                amountRange = nil
                reason = "no_available_quote"
            case let error as MixinAPIError:
                description = error.localizedDescription
                amountRange = nil
                reason = if error.isClientErrorResponse {
                    "client_error"
                } else if error.isServerErrorResponse {
                    "server_error"
                } else {
                    "other"
                }
            default:
                description = "\(error)"
                amountRange = nil
                reason = "other"
            }
            Logger.general.debug(category: "Swap", message: description)
            swapPriceContent = .error(description)
            self.amountRange = amountRange
            reporter.report(event: .tradeQuote, tags: ["type": "swap", "result": "failure", "reason": reason])
        }
    }
    
    func swapQuotePeriodicRequester(_ requester: SwapQuotePeriodicRequester, didCountDown value: Int) {
        let progress = Double(value) / Double(requester.refreshInterval)
        Logger.general.debug(category: "Swap", message: "Progress: \(progress)")
        swapPriceProgress = progress
        swapPriceCell?.footerInfoProgressView.setProgress(progress, animationDuration: 1)
    }
    
}

extension SwapViewController {
    
    struct AssetIDPair {
        let send: String
        let receive: String
    }
    
    static func loadTokenIDs() -> AssetIDPair? {
        let ids = AppGroupUserDefaults.Wallet.swapTokens
        return if ids.count == 2 {
            AssetIDPair(send: ids[0], receive: ids[1])
        } else {
            nil
        }
    }
    
    func saveTokenIDs() {
        guard
            let sendID = sendToken?.assetID,
            let receiveID = receiveToken?.assetID
        else {
            return
        }
        AppGroupUserDefaults.Wallet.swapTokens = [sendID, receiveID]
    }
    
}

extension SwapViewController {
    
    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        guard presentedViewController == nil else {
            return
        }
        swapAmountInputCell?.sendAmountTextField.becomeFirstResponder()
    }
    
    @objc private func inputAmountByRange(_ sender: Any) {
        guard
            let amountRange,
            let sendAmountTextField,
            let text = sendAmountTextField.text,
            let sendAmount = Decimal(string: text, locale: .current)
        else {
            return
        }
        if let minimum = amountRange.minimum, sendAmount < minimum {
            sendAmountTextField.text = userInputSimulationFormatter.string(from: minimum as NSDecimalNumber)
            sendAmountTextField.sendActions(for: .editingChanged)
        } else if let maximum = amountRange.maximum, sendAmount > maximum {
            sendAmountTextField.text = userInputSimulationFormatter.string(from: maximum as NSDecimalNumber)
            sendAmountTextField.sendActions(for: .editingChanged)
        }
    }
    
    private func reloadTokens() {
        RouteAPI.swappableTokens(source: tokenSource) { [weak self] result in
            switch result {
            case .success(let tokens):
                self?.reloadData(swappableTokens: tokens)
            case .failure(.requiresUpdate):
                self?.reportClientOutdated()
            case .failure(let error):
                Logger.general.debug(category: "Swap", message: "\(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.reloadTokens()
                }
            }
        }
    }
    
    private func reportClientOutdated() {
        let alert = UIAlertController(
            title: R.string.localizable.update_mixin(),
            message: R.string.localizable.app_update_tips(Bundle.main.shortVersionString),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: R.string.localizable.update(), style: .default, handler: { _ in
            self.navigationController?.popViewController(animated: false)
            UIApplication.shared.open(.mixinMessenger, options: [:], completionHandler: nil)
        }))
        alert.addAction(UIAlertAction(title: R.string.localizable.later(), style: .cancel, handler: { _ in
            self.navigationController?.popViewController(animated: true)
        }))
        self.present(alert, animated: true)
    }
    
    private func reloadData(swappableTokens: [SwapToken]) {
        DispatchQueue.global().async { [weak self, arbitrarySendAssetID, arbitraryReceiveAssetID] in
            let lastTokenIDs = Self.loadTokenIDs()
            let tokens = self?.balancedSwapTokens(from: swappableTokens) ?? [:]
            
            let sendToken: BalancedSwapToken?
            if let id = arbitrarySendAssetID ?? lastTokenIDs?.send {
                if let token = tokens[id] {
                    sendToken = token
                } else {
                    sendToken = self?.balancedSwapToken(assetID: id)
                }
            } else {
                sendToken = tokens.values.first { token in
                    token.assetID != arbitraryReceiveAssetID
                }
            }
            
            let receiveToken: BalancedSwapToken?
            if let id = arbitraryReceiveAssetID ?? lastTokenIDs?.receive {
                if id == sendToken?.assetID {
                    receiveToken = nil
                } else if let token = tokens[id] {
                    receiveToken = token
                } else {
                    receiveToken = self?.balancedSwapToken(assetID: id)
                }
            } else {
                receiveToken = tokens.values.first { token in
                    token.assetID != sendToken?.assetID
                }
            }
            
            let missingAssetID: String?
            if let id = arbitrarySendAssetID, id == arbitraryReceiveAssetID {
                missingAssetID = nil
            } else if let id = arbitrarySendAssetID, sendToken?.assetID != id {
                missingAssetID = id
            } else if let id = arbitraryReceiveAssetID, receiveToken?.assetID != id {
                missingAssetID = id
            } else {
                missingAssetID = nil
            }
            let missingAssetSymbol: String? = if let missingAssetID {
                TokenDAO.shared.symbol(assetID: missingAssetID)
            } else {
                nil
            }
            
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.swappableTokens = tokens
                self.sendToken = sendToken
                self.receiveToken = receiveToken
                if let missingAssetSymbol {
                    let description = R.string.localizable.swap_not_supported(missingAssetSymbol)
                    self.swapPriceContent = .error(description)
                }
            }
        }
    }
    
    private func updateCurrentPriceRepresentation(quote: SwapQuote) {
        let priceRepresentation = quote.priceRepresentation(unit: priceUnit)
        swapPriceContent = .price(priceRepresentation)
    }
    
    private func inputSendAmount(multiplier: Decimal) {
        guard let sendToken, let sendAmountTextField else {
            return
        }
        let amount = sendToken.decimalBalance * multiplier
        if amount >= 0.00000001 {
            sendAmountTextField.text = userInputSimulationFormatter.string(from: amount as NSDecimalNumber)
            sendAmountTextField.sendActions(for: .editingChanged)
        }
    }
    
}
