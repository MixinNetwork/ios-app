import UIKit
import MixinServices

final class AddCashInputAmountViewController: TokenConsumingInputAmountViewController {
    
    private let account: CashAccount
    private let tokenItem: MixinTokenItem
    private let traceID = UUID().uuidString.lowercased()
    private let receiverUserID = BotUserID.mixinCash
    
    private var receiver: UserItem?
    
    init(
        account: CashAccount,
        tokenItem: MixinTokenItem,
    ) {
        self.account = account
        self.tokenItem = tokenItem
        super.init(token: tokenItem, precision: MixinToken.internalPrecision)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let titleView = NavigationTitleView(title: R.string.localizable.send_to_title())
        titleView.subtitle = R.string.localizable.cash_account()
        titleView.subtitleStyle = .label(backgroundColor: R.color.cash_account()!)
        navigationItem.titleView = titleView
        
        let balanceStackView = {
            let titleLabel = UILabel()
            titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
            titleLabel.text = R.string.localizable.cash_balance()
            titleLabel.textColor = R.color.text_quaternary()
            titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            
            let apyLabel = InsetLabel()
            apyLabel.contentInset = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
            apyLabel.layer.cornerRadius = 4
            apyLabel.layer.masksToBounds = true
            apyLabel.backgroundColor = R.color.market_green()
            apyLabel.font = .preferredFont(forTextStyle: .caption1)
            apyLabel.adjustsFontForContentSizeCategory = true
            apyLabel.text = account.displayAPY
            apyLabel.textColor = .white
            apyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            
            let balanceLabel = UILabel()
            balanceLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
            balanceLabel.text = account.displayBalance + " " + Currency.usd.code
            balanceLabel.textColor = R.color.text_quaternary()
            balanceLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            
            let stackView = UIStackView(arrangedSubviews: [titleLabel, apyLabel, balanceLabel])
            stackView.spacing = 4
            return stackView
        }()
        accessoryStackView.insertArrangedSubview(balanceStackView, at: 0)
        balanceStackView.snp.makeConstraints { make in
            make.width.equalTo(view.snp.width).offset(-56)
        }
        
        tokenIconView.setIcon(token: tokenItem)
        tokenNameLabel.text = tokenItem.name
        tokenBalanceLabel.text = tokenItem.localizedBalanceWithSymbol
        DispatchQueue.global().async { [receiverUserID] in
            let cash = UserDAO.shared.getUser(userId: receiverUserID)
            DispatchQueue.main.async {
                self.receiver = cash
            }
        }
    }
    
    override func review(_ sender: Any) {
        guard !reviewButton.isBusy else {
            return
        }
        reviewButton.isBusy = true
        if let receiver {
            requestQuote(receiver: receiver)
        } else {
            UserAPI.showUser(userId: receiverUserID) { [weak self] result in
                switch result {
                case .success(let response):
                    DispatchQueue.global().async {
                        UserDAO.shared.updateUsers(users: [response])
                    }
                    let receiver = UserItem.createUser(from: response)
                    if let self {
                        self.receiver = receiver
                        self.requestQuote(receiver: receiver)
                    }
                case .failure(let error):
                    self?.updateViews(errorDescription: error.localizedDescription)
                }
            }
        }
    }
    
    override func reloadViewsWithBalanceRequirements() {
        if inputAmountRequirement.isSufficient {
            if token.decimalUSDPrice == 0 {
                updateViews(errorDescription: R.string.localizable.cash_account_invalid_token())
            } else if tokenAmount == 0 || tokenAmount * token.decimalUSDPrice >= account.decimalMinAmount {
                insufficientBalanceLabel.text = nil
                reviewButton.isEnabled = tokenAmount > 0
            } else {
                let minimum = R.string.localizable.cash_account_minimum_receive(
                    account.decimalMinAmount.formatted(),
                    Currency.usd.code
                )
                updateViews(errorDescription: minimum)
            }
        } else {
            insufficientBalanceLabel.text = R.string.localizable.insufficient_balance()
            reviewButton.isEnabled = false
        }
    }
    
    private func requestQuote(receiver: UserItem) {
        let amount = tokenAmount.formatted(
            MixinToken.transferCanonicalFormatStyle
        )
        let request = QuoteRequest(
            inputMint: tokenItem.assetID,
            outputMint: AssetID.solanaUSDC,
            amount: amount,
            slippage: Slippage(decimal: 0.01).integral,
            source: .mixin
        )
        _ = RouteAPI.quote(request: request) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .success(let response):
                if let receiveAmount = Decimal(string: response.outAmount, locale: .enUSPOSIX) {
                    if receiveAmount >= account.decimalMinAmount {
                        self.prepareForPayment(receiver: receiver, receiveAmount: receiveAmount)
                    } else {
                        self.updateViews(errorDescription: R.string.localizable.cash_account_invalid_amount())
                    }
                } else {
                    self.updateViews(errorDescription: R.string.localizable.error_network_task_failed())
                }
            case .failure(.response(.noAvailableQuote)), .failure(.response(.tokenPairNotSupported)):
                self.updateViews(errorDescription: R.string.localizable.cash_account_invalid_token())
            case .failure(.response(.invalidQuoteAmount)):
                self.updateViews(errorDescription: R.string.localizable.cash_account_invalid_amount())
            case .failure(let error):
                self.updateViews(errorDescription: error.localizedDescription)
            }
        }
    }
    
    private func prepareForPayment(receiver: UserItem, receiveAmount: Decimal) {
        let payment = Payment(
            traceID: traceID,
            token: tokenItem,
            tokenAmount: tokenAmount,
            fiatMoneyAmount: receiveAmount,
            memo: "",
            context: .cash,
        )
        let onPreconditonFailure = { [weak self] (reason: PaymentPreconditionFailureReason) in
            self?.updateViewsForSuccess()
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
        ) { [account, weak self] (operation, issues) in
            self?.updateViewsForSuccess()
            let preview = AddCashPreviewViewController(
                account: account,
                addingAmount: receiveAmount,
                operation: operation
            )
            UIApplication.homeContainerViewController?.present(preview, animated: true)
        }
    }
    
    private func updateViewsForSuccess() {
        reviewButton.isBusy = false
        insufficientBalanceLabel.text = nil
        reviewButton.isEnabled = true
    }
    
    private func updateViews(errorDescription: String) {
        reviewButton.isBusy = false
        insufficientBalanceLabel.text = errorDescription
        reviewButton.isEnabled = false
    }
    
}
