import UIKit
import OrderedCollections
import MixinServices

class TradeViewController: UIViewController {
    
    enum Mode: Int, CaseIterable {
        case simple
        case advanced
    }
    
    private enum Section: Int, CaseIterable {
        case modeSelector
        case amountInput
        case priceInput
        case simpleModePrice
        case openOrders
        case expiry
    }
    
    private enum PriceInputAccessory: Equatable {
        case available(isSellingToken: Bool)
        case unavailable
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var reviewButtonWrapperView: UIView!
    @IBOutlet weak var reviewButton: RoundedButton!
    
    let pricingModel = TradePricingModel()
    let openOrderRequester: PendingTradeOrderLoader
    
    var mode: Mode {
        didSet {
            switch mode {
            case .simple:
                openOrderRequester.pause()
            case .advanced:
                quoteRequester?.stop()
                quoteRequester = nil
            }
            reloadSections(mode: mode)
            switch mode {
            case .simple:
                scheduleNewRequesterIfAvailable()
            case .advanced:
                openOrderRequester.start(after: 0)
            }
        }
    }
    
    var sendToken: BalancedSwapToken? {
        pricingModel.sendToken
    }
    
    var receiveToken: BalancedSwapToken? {
        pricingModel.receiveToken
    }
    
    var orderWalletID: String? {
        nil
    }
    
    private(set) weak var showOrdersItem: BadgeBarButtonItem?
    
    // Key is asset id
    private(set) var swappableTokens: OrderedDictionary<String, BalancedSwapToken> = [:]
    private(set) var quote: SwapQuote?
    
    private let arbitrarySendAssetID: String?
    private let arbitraryReceiveAssetID: String?
    private let tokenSource: RouteTokenSource
    private let footerReuseIdentifier = "f"
    
    private lazy var tokenAmountRoundingHandler = NSDecimalNumberHandler(
        roundingMode: .plain,
        scale: MixinToken.internalPrecision,
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )
    
    private var showReviewWrapperConstraints: [NSLayoutConstraint] = []
    private var hideReviewWrapperConstraints: [NSLayoutConstraint] = []
    
    private var sections: [Section] = []
    private var contentSizeObservation: NSKeyValueObservation?
    private var quoteRequester: SwapQuotePeriodicRequester?
    private var amountRange: SwapQuotePeriodicRequester.AmountRange?
    private var openOrders: [TradeOrderViewModel] = []
    
    // TradeAmountInputCell
    private weak var amountInputCell: TradeAmountInputCell?
    
    private var sendViewStyle: TradeTokenSelectorStyle = .loading {
        didSet {
            amountInputCell?.updateSendView(style: sendViewStyle)
        }
    }
    
    private var receiveViewStyle: TradeTokenSelectorStyle = .loading {
        didSet {
            amountInputCell?.updateReceiveView(style: receiveViewStyle)
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
    
    // TradePriceInputCell
    private weak var priceInputCell: TradePriceInputCell?
    
    private var priceInputAccessory: PriceInputAccessory = .unavailable {
        didSet {
            guard priceInputAccessory != oldValue, let priceInputCell else {
                return
            }
            updatePriceInputAccessoryView(
                cell: priceInputCell,
                accessory: priceInputAccessory
            )
        }
    }
    
    // TradeExpirySelectorCell
    private(set) var selectedExpiry: TradeOrder.Expiry = .never
    
    init(
        mode: Mode,
        openOrderRequester: PendingTradeOrderLoader,
        tokenSource: RouteTokenSource,
        sendAssetID: String?,
        receiveAssetID: String?
    ) {
        self.mode = mode
        self.openOrderRequester = openOrderRequester
        self.tokenSource = tokenSource
        self.arbitrarySendAssetID = sendAssetID
        self.arbitraryReceiveAssetID = receiveAssetID
        let nib = R.nib.tradeView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let showOrdersItem = BadgeBarButtonItem(
            image: R.image.ic_title_transaction()!,
            target: self,
            action: #selector(showOrders(_:))
        )
        navigationItem.rightBarButtonItems = [
            .customerService(
                target: self,
                action: #selector(presentCustomerService(_:))
            ),
            showOrdersItem,
        ]
        self.showOrdersItem = showOrdersItem
        
        pricingModel.delegate = self
        
        showReviewWrapperConstraints = [
            reviewButtonWrapperView.bottomAnchor.constraint(
                equalTo: view.keyboardLayoutGuide.topAnchor
            ),
            collectionView.bottomAnchor.constraint(
                equalTo: reviewButtonWrapperView.topAnchor
            ),
        ]
        hideReviewWrapperConstraints = [
            collectionView.bottomAnchor.constraint(
                equalTo: view.keyboardLayoutGuide.topAnchor
            ),
            reviewButtonWrapperView.topAnchor.constraint(
                equalTo: view.bottomAnchor
            ),
        ]
        switch mode {
        case .simple:
            showReviewButtonWrapperView()
        case .advanced:
            hideReviewButtonWrapperView()
        }
        NSLayoutConstraint.activate(showReviewWrapperConstraints)
        NSLayoutConstraint.activate(hideReviewWrapperConstraints)
        
        collectionView.register(
            R.nib.openTradeOrderHeaderView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        collectionView.register(
            OpenOrderFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: footerReuseIdentifier
        )
        collectionView.register(R.nib.exploreSegmentCell)
        collectionView.register(R.nib.tradeAmountInputCell)
        collectionView.register(R.nib.tradePriceInputCell)
        collectionView.register(R.nib.swapPriceCell)
        collectionView.register(R.nib.noOpenTradeOrderCell)
        collectionView.register(R.nib.tradeOrderCell)
        collectionView.register(R.nib.tradeExpirySelectorCell)
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
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(238))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(238))
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
                if let orders = self?.openOrders, !orders.isEmpty {
                    let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(70))
                    let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                    let section = NSCollectionLayoutSection(group: group)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    section.boundarySupplementaryItems = [
                        NSCollectionLayoutBoundarySupplementaryItem(
                            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(57)),
                            elementKind: UICollectionView.elementKindSectionHeader,
                            alignment: .top
                        ),
                        NSCollectionLayoutBoundarySupplementaryItem(
                            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(20)),
                            elementKind: UICollectionView.elementKindSectionFooter,
                            alignment: .bottom
                        ),
                    ]
                    return section
                } else {
                    let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(211))
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(211))
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
                }
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
        collectionView.allowsMultipleSelection = true
        collectionView.dataSource = self
        collectionView.delegate = self
        reloadSections(mode: mode)
        
        reloadTokens()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateOrdersButton),
            name: Web3OrderDAO.didSaveNotification,
            object: nil
        )
        updateOrdersButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        switch mode {
        case .simple:
            quoteRequester?.start(delay: 0)
        case .advanced:
            openOrderRequester.start(after: 0)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        quoteRequester?.stop()
        openOrderRequester.pause()
    }
    
    @IBAction func review(_ sender: RoundedButton) {
        
    }
    
    @objc func showOrders(_ sender: Any) {
        BadgeManager.shared.setHasViewed(identifier: .swapOrder)
        if let showOrdersItem, showOrdersItem.compatibleBadge == .unread {
            showOrdersItem.compatibleBadge = nil
        }
    }
    
    @objc func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "trade_home"])
    }
    
    @objc func sendAmountEditingChanged(_ sender: UITextField) {
        amountRange = nil
        pricingModel.sendAmount = if let text = sender.text {
            Decimal(string: text, locale: .current)
        } else {
            nil
        }
        reloadSections(mode: mode)
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
    
    @objc func togglePriceUnit(_ sender: Any) {
        pricingModel.displayPriceNumeraire.toggle()
    }
    
    @objc func priceEditingChanged(_ sender: UITextField) {
        pricingModel.displayPrice = sender.text
    }
    
    func prepareForReuse(sender: Any) {
        pricingModel.prepareForReuse()
        amountInputCell?.updateSendAmountTextField(amount: nil)
        reloadTokens() // Update send token balance
        reloadSections(mode: mode)
    }
    
    func setSendToken(_ sendToken: BalancedSwapToken?) {
        sendViewStyle = if let sendToken {
            .token(sendToken)
        } else {
            .selectable
        }
        pricingModel.sendToken = sendToken
        updatePriceInputAccessory()
        setAutoPriceUnit()
        scheduleNewRequesterIfAvailable()
        saveTokenIDs()
        updateMarkets()
    }
    
    func setReceiveToken(_ receiveToken: BalancedSwapToken?) {
        receiveViewStyle = if let receiveToken {
            .token(receiveToken)
        } else {
            .selectable
        }
        pricingModel.receiveToken = receiveToken
        updatePriceInputAccessory()
        setAutoPriceUnit()
        scheduleNewRequesterIfAvailable()
        saveTokenIDs()
        updateMarkets()
    }
    
    func swapSendingReceiving() {
        swap(&sendViewStyle, &receiveViewStyle)
        pricingModel.swapSendingReceiving()
        updatePriceInputAccessory()
        setAutoPriceUnit()
        scheduleNewRequesterIfAvailable()
        saveTokenIDs()
        updateMarkets()
    }
    
    func balancedSwapToken(assetID: String) -> BalancedSwapToken? {
        nil
    }
    
    func balancedSwapTokens(
        from swappableTokens: [SwapToken]
    ) -> OrderedDictionary<String, BalancedSwapToken> {
        [:]
    }
    
    func reload(openOrders: [TradeOrderViewModel]) {
        self.openOrders = openOrders
        if let section = sections.firstIndex(of: .openOrders) {
            UIView.performWithoutAnimation {
                let sections = IndexSet(integer: section)
                collectionView.reloadSections(sections)
            }
        }
    }
    
}

extension TradeViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension TradeViewController: UICollectionViewDataSource {
    
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
                R.string.localizable.trade_simple()
            case .advanced:
                R.string.localizable.trade_advanced()
            }
            return cell
        case .amountInput:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.trade_amount_input, for: indexPath)!
            if amountInputCell != cell {
                let inputAccessoryView = TradeInputAccessoryView(
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
                    action: #selector(swapSendingReceivingWithAnimation(_:)),
                    for: .touchUpInside
                )
                amountInputCell = cell
            }
            cell.updateSendView(style: sendViewStyle)
            cell.updateSendAmountTextField(amount: pricingModel.sendAmount)
            cell.updateReceiveAmountTextField(amount: pricingModel.receiveAmount)
            cell.updateReceiveView(style: receiveViewStyle)
            return cell
        case .priceInput:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.trade_price_input, for: indexPath)!
            cell.textField.text = pricingModel.displayPrice
            switch pricingModel.displayPriceNumeraire {
            case .send:
                cell.update(style: receiveViewStyle)
            case .receive:
                cell.update(style: sendViewStyle)
            }
            cell.load(priceRepresentation: pricingModel.priceEquation())
            if priceInputCell != cell {
                updatePriceInputAccessoryView(
                    cell: cell,
                    accessory: priceInputAccessory
                )
                cell.textField.addTarget(
                    self,
                    action: #selector(priceEditingChanged(_:)),
                    for: .editingChanged
                )
                cell.togglePriceUnitButton.addTarget(
                    self,
                    action: #selector(togglePriceUnit(_:)),
                    for: .touchUpInside
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
                cell.togglePriceUnitButton.addTarget(
                    self,
                    action: #selector(togglePriceUnit(_:)),
                    for: .touchUpInside
                )
                swapPriceCell = cell
            }
            cell.footerInfoProgressView.setProgress(swapPriceProgress, animationDuration: nil)
            return cell
        case .openOrders:
            if openOrders.isEmpty {
                return collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.no_open_trade_order, for: indexPath)!
            } else {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.trade_order, for: indexPath)!
                let viewModel = openOrders[indexPath.item]
                cell.load(viewModel: viewModel)
                return cell
            }
        case .expiry:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.trade_expiry_selector, for: indexPath)!
            cell.selectedExpiry = selectedExpiry
            cell.onChange = { [weak self] expiry in
                self?.selectedExpiry = expiry
            }
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: R.reuseIdentifier.open_trade_order_header, for: indexPath)!
            view.label.text = R.string.localizable.open_orders_count(openOrders.count)
            return view
        default:
            return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: footerReuseIdentifier, for: indexPath)
        }
    }
    
}

extension TradeViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        let section = sections[indexPath.section]
        return section == .modeSelector || section == .openOrders
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        false
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .modeSelector:
            collectionView.indexPathsForSelectedItems?.forEach { selectedIndexPath in
                if selectedIndexPath.section == indexPath.section,
                   selectedIndexPath.item != indexPath.item
                {
                    collectionView.deselectItem(at: selectedIndexPath, animated: false)
                }
            }
            mode = Mode(rawValue: indexPath.item)!
        case .openOrders:
            collectionView.deselectItem(at: indexPath, animated: true)
            let viewModel = openOrders[indexPath.item]
            let viewController = TradeOrderViewController(viewModel: viewModel)
            navigationController?.pushViewController(viewController, animated: true)
        default:
            break
        }
    }
    
}

extension TradeViewController: UITextFieldDelegate {
    
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

extension TradeViewController: TradePricingModel.Delegate {
    
    func swapPricingModel(_ model: TradePricingModel, didUpdate updates: [TradePricingModel.Update]) {
        for update in updates {
            switch update {
            case .receiveAmount(let amount):
                amountInputCell?.updateReceiveAmountTextField(amount: amount)
            case .displayPrice(let text):
                priceInputCell?.textField.text = text
            case .priceToken(let token):
                if let token {
                    priceInputCell?.update(style: .token(token))
                } else {
                    priceInputCell?.update(style: .selectable)
                }
            case .priceEquation(let text):
                priceInputCell?.load(priceRepresentation: text)
                if let text {
                    swapPriceContent = .price(text)
                } else {
                    swapPriceContent = .calculating
                }
            }
        }
        switch mode {
        case .simple:
            break
        case .advanced:
            if let sendAmount = model.sendAmount, let sendToken = model.sendToken {
                if sendAmount > sendToken.decimalBalance {
                    reviewButton.setTitle(R.string.localizable.insufficient_balance(), for: .normal)
                    reviewButton.isEnabled = false
                } else {
                    reviewButton.setTitle(R.string.localizable.review(), for: .normal)
                    reviewButton.isEnabled = model.receiveAmount != nil
                }
            } else {
                reviewButton.setTitle(R.string.localizable.review(), for: .normal)
                reviewButton.isEnabled = false
            }
        }
    }
    
}

extension TradeViewController: SwapQuotePeriodicRequesterDelegate {
    
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
            pricingModel.receiveAmount = quote.receiveAmount
            amountInputCell?.updateReceiveAmountTextField(amount: quote.receiveAmount)
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

extension TradeViewController {
    
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

extension TradeViewController {
    
    @objc private func updateOrdersButton() {
        assert(Thread.isMainThread)
        guard let showOrdersItem, let walletID = orderWalletID else {
            return
        }
        let swapOrdersUnread = !BadgeManager.shared.hasViewed(identifier: .swapOrder)
        DispatchQueue.global().async { [weak showOrdersItem] in
            let pendingOrdersCount = min(
                99,
                Web3OrderDAO.shared.pendingOrdersCount(walletID: walletID)
            )
            let badge: BadgeBarButtonView.Badge? = if pendingOrdersCount != 0 {
                .count(pendingOrdersCount)
            } else if swapOrdersUnread {
                .unread
            } else {
                nil
            }
            DispatchQueue.main.async {
                showOrdersItem?.compatibleBadge = badge
            }
        }
    }
    
    @objc private func swapSendingReceivingWithAnimation(_ sender: Any) {
        if let sender = sender as? UIButton, sender == amountInputCell?.swapButton {
            let animation = CABasicAnimation(keyPath: "transform.rotation")
            animation.fromValue = 0
            animation.toValue = CGFloat.pi
            animation.duration = 0.35
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            sender.layer.add(animation, forKey: nil)
        }
        swapSendingReceiving()
    }
    
    @objc private func inputAmountByRange(_ sender: Any) {
        guard let amountRange, let sendAmount = pricingModel.sendAmount else {
            return
        }
        if let minimum = amountRange.minimum, sendAmount < minimum {
            pricingModel.sendAmount = minimum
            amountInputCell?.updateSendAmountTextField(amount: minimum)
        } else if let maximum = amountRange.maximum, sendAmount > maximum {
            pricingModel.sendAmount = maximum
            amountInputCell?.updateSendAmountTextField(amount: maximum)
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
    
    func reloadSections(mode: Mode) {
        let sections: [Section] = switch mode {
        case .simple:
            [.modeSelector, .amountInput, .simpleModePrice]
        case .advanced:
            if let sendAmount = pricingModel.sendAmount, sendAmount != 0 {
                [.modeSelector, .amountInput, .priceInput, .expiry]
            } else {
                [.modeSelector, .amountInput, .priceInput, .openOrders]
            }
        }
        if sections != self.sections {
            let switchingBetweenModes = sections.count != self.sections.count
            self.sections = sections
            if switchingBetweenModes {
                pricingModel.sendAmount = nil
                collectionView.reloadData()
                if let section = sections.firstIndex(of: .modeSelector) {
                    let indexPath = IndexPath(item: mode.rawValue, section: section)
                    collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                }
            } else {
                UIView.performWithoutAnimation {
                    let sections = IndexSet(integer: sections.count - 1)
                    collectionView.reloadSections(sections)
                }
            }
            if sections.contains(.openOrders) {
                hideReviewButtonWrapperView()
            } else {
                showReviewButtonWrapperView()
            }
            view.layoutSubviews()
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
    
    private func showReviewButtonWrapperView() {
        for constraint in showReviewWrapperConstraints {
            constraint.priority = .almostRequired
        }
        for constraint in hideReviewWrapperConstraints {
            constraint.priority = .almostInexist
        }
    }
    
    private func hideReviewButtonWrapperView() {
        for constraint in showReviewWrapperConstraints {
            constraint.priority = .almostInexist
        }
        for constraint in hideReviewWrapperConstraints {
            constraint.priority = .almostRequired
        }
    }
    
    private func updatePriceInputAccessory() {
        guard let sendToken, let receiveToken else {
            priceInputAccessory = .unavailable
            return
        }
        let price = pricingModel.derivePrice(
            sendToken: sendToken,
            receiveToken: receiveToken
        )
        guard price != nil else {
            priceInputAccessory = .unavailable
            return
        }
        let isSellingToken = AssetID.stablecoins.contains(receiveToken.assetID)
        priceInputAccessory = .available(isSellingToken: isSellingToken)
    }
    
    private func updatePriceInputAccessoryView(
        cell: TradePriceInputCell,
        accessory: PriceInputAccessory
    ) {
        let accessoryView: TradeInputAccessoryView
        if let view = cell.textField.inputAccessoryView as? TradeInputAccessoryView {
            accessoryView = view
        } else {
            accessoryView = TradeInputAccessoryView(
                frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44)
            )
            accessoryView.onDone = { [weak textField=cell.textField] in
                textField?.resignFirstResponder()
            }
            cell.textField.inputAccessoryView = accessoryView
        }
        switch accessory {
        case .unavailable:
            accessoryView.items = []
        case .available(let isSellingToken):
            accessoryView.items = if isSellingToken {
                [
                    .init(title: R.string.localizable.current_market_price()) { [weak self] in
                        self?.inputPrice(multiplier: 1)
                    },
                    .init(title: "+10%") { [weak self] in
                        self?.inputPrice(multiplier: 1.1)
                    },
                    .init(title: "+20%") { [weak self] in
                        self?.inputPrice(multiplier: 1.2)
                    },
                ]
            } else {
                [
                    .init(title: R.string.localizable.current_market_price()) { [weak self] in
                        self?.inputPrice(multiplier: 1)
                    },
                    .init(title: "-10%") { [weak self] in
                        self?.inputPrice(multiplier: 1 / 0.9)
                    },
                    .init(title: "-20%") { [weak self] in
                        self?.inputPrice(multiplier: 1 / 0.8)
                    },
                ]
            }
        }
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
                self.setSendToken(sendToken)
                self.setReceiveToken(receiveToken)
                if let missingAssetSymbol {
                    let description = R.string.localizable.swap_not_supported(missingAssetSymbol)
                    self.swapPriceContent = .error(description)
                }
                self.updateMarkets()
            }
        }
    }
    
    private func inputSendAmount(multiplier: Decimal) {
        guard let sendToken else {
            return
        }
        let amount = NSDecimalNumber(decimal: sendToken.decimalBalance * multiplier)
            .rounding(accordingToBehavior: tokenAmountRoundingHandler)
            .decimalValue
        if amount >= MixinToken.minimalAmount {
            pricingModel.sendAmount = amount
            amountInputCell?.updateSendAmountTextField(amount: amount)
            scheduleNewRequesterIfAvailable()
        }
    }
    
    private func inputPrice(multiplier: Decimal) {
        updateMarkets()
        guard let sendToken, let receiveToken else {
            return
        }
        let price = pricingModel.derivePrice(
            sendToken: sendToken,
            receiveToken: receiveToken
        )
        guard let price else {
            return
        }
        pricingModel.price = NSDecimalNumber(decimal: price * multiplier)
            .rounding(accordingToBehavior: tokenAmountRoundingHandler)
            .decimalValue
    }
    
    private func scheduleNewRequesterIfAvailable() {
        guard mode == .simple else {
            return
        }
        pricingModel.receiveAmount = nil
        amountInputCell?.updateReceiveAmountTextField(amount: nil)
        quote = nil
        reviewButton.isEnabled = false
        quoteRequester?.stop()
        quoteRequester = nil
        guard
            let sendAmount = pricingModel.sendAmount,
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
        self.quoteRequester = requester
        requester.start(delay: 1)
    }
    
    private func updateMarkets() {
        var ids: [String] = []
        if let sendToken {
            ids.append(sendToken.assetID)
        }
        if let receiveToken {
            ids.append(receiveToken.assetID)
        }
        RouteAPI.markets(ids: ids, queue: .global()) { result in
            switch result {
            case let .success(markets):
                MarketDAO.shared.save(markets: markets)
                Logger.general.debug(category: "MarketRequester", message: "Saved")
            case .failure:
                break
            }
        }
    }
    
    private func setAutoPriceUnit() {
        let isSendingStablecoin = if let sendToken {
            AssetID.stablecoins.contains(sendToken.assetID)
        } else {
            false
        }
        let isReceivingStablecoin = if let receiveToken {
            AssetID.stablecoins.contains(receiveToken.assetID)
        } else {
            false
        }
        if isSendingStablecoin && !isReceivingStablecoin {
            if pricingModel.displayPriceNumeraire != .receive {
                pricingModel.displayPriceNumeraire = .receive
            }
        } else {
            if pricingModel.displayPriceNumeraire != .send {
                pricingModel.displayPriceNumeraire = .send
            }
        }
    }
    
}

extension TradeViewController {
    
    final class OpenOrderFooterView: UICollectionReusableView {
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            updateStyle()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            updateStyle()
        }
        
        private func updateStyle() {
            backgroundColor = R.color.background()
            layer.cornerRadius = 8
            layer.masksToBounds = true
            layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        
    }
    
}
