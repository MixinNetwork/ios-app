import UIKit
import MixinServices

final class WithdrawToWeb3WalletInputAmountViewController: InputAmountViewController {
    
    override var token: any TransferableToken {
        tokenItem
    }
    
    private let tokenItem: TokenItem
    private let web3WalletAddress: String
    private let web3WalletChainName: String
    private let traceID = UUID().uuidString.lowercased()
    
    private var fee: WithdrawFeeItem?
    
    init(tokenItem: TokenItem, web3WalletAddress: String, web3WalletChainName: String) {
        self.tokenItem = tokenItem
        self.web3WalletAddress = web3WalletAddress
        self.web3WalletChainName = web3WalletChainName
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let address = Address.compactRepresentation(of: web3WalletAddress)
        title = R.string.localizable.send()
        navigationItem.titleView = NavigationTitleView(
            title: R.string.localizable.send(),
            subtitle: address
        )
        tokenIconView.setIcon(token: tokenItem)
        tokenNameLabel.text = tokenItem.name
        tokenBalanceLabel.text = tokenItem.localizedBalanceWithSymbol
        reloadWithdrawFee(with: tokenItem, address: web3WalletAddress)
    }
    
    override func review(_ sender: Any) {
        guard let fee else {
            return
        }
        reviewButton.isBusy = true
        let tokenAmount = self.tokenAmount
        let fiatMoneyAmount = self.fiatMoneyAmount
        let amountIntent = self.amountIntent
        let payment = Payment(traceID: traceID,
                              token: tokenItem,
                              tokenAmount: tokenAmount,
                              fiatMoneyAmount: fiatMoneyAmount,
                              memo: "")
        let destination: Payment.WithdrawalDestination = .web3(address: web3WalletAddress, chain: web3WalletChainName)
        payment.checkPreconditions(withdrawTo: destination, fee: fee, on: self) { reason in
            self.reviewButton.isBusy = false
            switch reason {
            case .userCancelled, .loggedOut:
                break
            case .description(let message):
                showAutoHiddenHud(style: .error, text: message)
            }
        } onSuccess: { operation, issues in
            self.reviewButton.isBusy = false
            let preview = WithdrawPreviewViewController(issues: issues,
                                                        operation: operation,
                                                        amountDisplay: amountIntent,
                                                        withdrawalTokenAmount: tokenAmount,
                                                        withdrawalFiatMoneyAmount: fiatMoneyAmount,
                                                        addressLabel: nil)
            self.present(preview, animated: true)
        }
    }
    
    private func reloadWithdrawFee(with token: TokenItem, address: String) {
        reviewButton.isBusy = true
        Task.detached {
            do {
                let fees = try await SafeAPI.fees(assetID: token.assetID, destination: address)
                guard let fee = fees.first else {
                    throw MixinAPIResponseError.withdrawSuspended
                }
                let allAssetIDs = fees.map(\.assetID)
                let missingAssetIDs = TokenDAO.shared.inexistAssetIDs(in: allAssetIDs)
                if !missingAssetIDs.isEmpty {
                    let tokens = try await SafeAPI.assets(ids: missingAssetIDs)
                    await withCheckedContinuation { continuation in
                        TokenDAO.shared.save(assets: tokens) {
                            continuation.resume()
                        }
                    }
                }
                let tokensMap = TokenDAO.shared.tokenItems(with: allAssetIDs)
                    .reduce(into: [:]) { result, item in
                        result[item.assetID] = item
                    }
                let feeTokens: [WithdrawFeeItem] = fees.compactMap { fee in
                    if let token = tokensMap[fee.assetID] {
                        return WithdrawFeeItem(amountString: fee.amount, tokenItem: token)
                    } else {
                        return nil
                    }
                }
                guard let feeToken = feeTokens.first, feeToken.tokenItem.assetID == fee.assetID else {
                    return
                }
                await MainActor.run {
                    self.fee = feeToken
                    self.reviewButton.isBusy = false
                }
            } catch MixinAPIResponseError.withdrawSuspended {
                await MainActor.run {
                    let suspended = WalletHintViewController(content: .withdrawSuspended(token))
                    suspended.delegate = self
                    self.present(suspended, animated: true)
                }
            } catch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    // Check token and address
                    self?.reloadWithdrawFee(with: token, address: address)
                }
            }
        }
    }
    
}

extension WithdrawToWeb3WalletInputAmountViewController: WalletHintViewControllerDelegate {
    
    func walletHintViewControllerDidRealize(_ controller: WalletHintViewController) {
        navigationController?.popViewController(animated: true)
    }
    
    func walletHintViewControllerWantsContactSupport(_ controller: WalletHintViewController) {
        guard let navigationController, let user = UserDAO.shared.getUser(identityNumber: "7000") else {
            return
        }
        let conversation = ConversationViewController.instance(ownerUser: user)
        var viewControllers = navigationController.viewControllers
        if let index = viewControllers.firstIndex(where: { $0 is HomeTabBarController }) {
            viewControllers.removeLast(viewControllers.count - index - 1)
        }
        viewControllers.append(conversation)
        navigationController.setViewControllers(viewControllers, animated: true)
    }
    
}
