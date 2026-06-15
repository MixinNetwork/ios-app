import UIKit
import MixinServices

final class CommonWalletOverviewActionHandler {
    
    private let wallet: Web3Wallet
    private let supportedChainIDs: Set<String>
    private let watchingAddresses: WatchingAddresses?
    private let tradeSource: UserOperationAnalytics.TradeSource
    
    private weak var responder: UIViewController?
    
    init(
        wallet: Web3Wallet,
        supportedChainIDs: Set<String>,
        watchingAddresses: WatchingAddresses?,
        tradeSource: UserOperationAnalytics.TradeSource,
        responder: UIViewController?,
    ) {
        self.wallet = wallet
        self.supportedChainIDs = supportedChainIDs
        self.watchingAddresses = watchingAddresses
        self.tradeSource = tradeSource
        self.responder = responder
    }
    
}

extension CommonWalletOverviewActionHandler: AssetChangeAccountRecoveryChecking {
    
    var accountRecoverCheckingResponder: UIViewController? {
        responder
    }
    
}

extension CommonWalletOverviewActionHandler: WalletActionHandler {
    
    func buy() {
        let buy = BuyTokenInputAmountViewController(wallet: .common(wallet))
        responder?.navigationController?.pushViewController(buy, animated: true)
        reporter.report(event: .buyStart, tags: ["wallet": "web3", "source": tradeSource.rawValue])
    }
    
    func receive() {
        reporter.report(event: .receiveStart, tags: ["wallet": "web3", "source": tradeSource.rawValue])
        let selector = Web3TokenSelectorViewController(
            wallet: wallet,
            supportedChainIDs: supportedChainIDs,
            intent: .receive,
        )
        selector.onSelected = { [wallet, weak responder] token in
            reporter.report(event: .receiveTokenSelect)
            let selector = Web3TokenSenderSelectorViewController(
                receivingWallet: wallet,
                receivingToken: token
            )
            responder?.navigationController?.pushViewController(selector, animated: true)
        }
        withAccountRecoveryChecked { [weak responder] in
            responder?.present(selector, animated: true, completion: nil)
        }
    }
    
}

extension CommonWalletOverviewActionHandler: WalletOverviewCell.Delegate {
    
    func walletOverviewCell(_ cell: WalletOverviewCell, didSelectTokenAction action: TokenAction) {
        switch action {
        case .buy:
            buy()
        case .send:
            let selector = Web3TokenSelectorViewController(
                wallet: wallet,
                supportedChainIDs: supportedChainIDs,
                intent: .send,
            )
            selector.onSelected = { [wallet, weak responder] token in
                guard
                    let chain = Web3Chain.chain(chainID: token.chainID),
                    let address = Web3AddressDAO.shared.address(walletID: wallet.walletID, chainID: chain.chainID)
                else {
                    return
                }
                let payment = Web3SendingTokenPayment(
                    wallet: wallet,
                    chain: chain,
                    token: token,
                    fromAddress: address
                )
                let selector = Web3TokenReceiverViewController(payment: payment)
                responder?.navigationController?.pushViewController(selector, animated: true)
            }
            withAccountRecoveryChecked { [weak responder] in
                responder?.present(selector, animated: true, completion: nil)
            }
        case .receive:
            receive()
        case .trade:
            UserOperationAnalytics.tradeSource = .walletHome
            let trade = TradeViewController(
                wallet: .common(wallet),
                supportedChainIDs: supportedChainIDs,
                trading: nil,
                sendAssetID: nil,
                receiveAssetID: nil,
                referral: nil
            )
            guard let trade else {
                return
            }
            withAccountRecoveryChecked { [weak responder] in
                responder?.navigationController?.pushViewController(trade, animated: true)
            }
        }
    }
    
    func walletOverviewCell(_ cell: WalletOverviewCell, didSelectImportAction action: WalletOverview.ImportSecretAction) {
        switch action {
        case .importPrivateKey:
            if let kind = Web3Chain.Kind.singleKindWallet(chainIDs: supportedChainIDs) {
                let validation = AddWalletPINValidationViewController(
                    action: .reimportPrivateKey(wallet, kind)
                )
                responder?.navigationController?.pushViewController(validation, animated: true)
            }
        case .importMnemonics:
            let validation = AddWalletPINValidationViewController(action: .reimportMnemonics(wallet))
            responder?.navigationController?.pushViewController(validation, animated: true)
        }
    }
    
    func walletOverviewCellDidSelectPendingDeposits(_ cell: WalletOverviewCell) {
        
    }
    
    func walletOverviewCellDidSelectPendingTransactions(_ cell: WalletOverviewCell) {
        let transactionHistory = Web3TransactionHistoryViewController(wallet: wallet, type: .pending)
        responder?.navigationController?.pushViewController(transactionHistory, animated: true)
    }
    
    func walletOverviewCellDidSelectWatchingAddresses(_ cell: WalletOverviewCell) {
        guard let addresses = watchingAddresses?.addresses, !addresses.isEmpty else {
            return
        }
        let description = WatchWalletAddressesViewController(addresses: addresses)
        responder?.navigationController?.pushViewController(description, animated: true)
    }
    
}
