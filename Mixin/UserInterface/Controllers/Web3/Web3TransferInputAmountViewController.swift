import UIKit

final class Web3TransferInputAmountViewController: InputAmountViewController {
    
    override var token: any Web3TransferableToken {
        payment.token
    }
    
    private let payment: Web3SendingTokenToAddressPayment
    
    init(payment: Web3SendingTokenToAddressPayment) {
        self.payment = payment
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tokenIconView.setIcon(web3Token: payment.token)
        tokenNameLabel.text = payment.token.name
        tokenBalanceLabel.text = payment.token.localizedBalanceWithSymbol
        container?.setSubtitle(subtitle: payment.toAddressCompactRepresentation)
        inputMaxValueButton.isHidden = payment.sendingNativeToken
    }
    
    override func review(_ sender: Any) {
        let amount = tokenAmount
        reviewButton.isEnabled = false
        reviewButton.isBusy = true
        
        func transfer(proposer: Web3TransferViewController.Proposer) {
            DispatchQueue.global().async { [payment] in
                let initError: Error?
                do {
                    let operation = switch payment.chain.kind {
                    case .evm:
                        try EVMTransferToAddressOperation(payment: payment, decimalAmount: amount)
                    case .solana:
                        try SolanaTransferToAddressOperation(payment: payment, decimalAmount: amount)
                    }
                    DispatchQueue.main.async {
                        let transfer = Web3TransferViewController(operation: operation, proposer: proposer)
                        transfer.manipulateNavigationStackOnFinished = true
                        Web3PopupCoordinator.enqueue(popup: .request(transfer))
                    }
                    initError = nil
                } catch {
                    initError = error
                }
                DispatchQueue.main.async {
                    if let initError {
                        showAutoHiddenHud(style: .error, text: "\(initError)")
                    }
                    self.reviewButton.isEnabled = true
                    self.reviewButton.isBusy = false
                }
            }
        }
        
        switch payment.toType {
        case .mixinWallet:
            transfer(proposer: .web3ToMixinWallet)
        case .arbitrary:
            transfer(proposer: .web3ToAddress)
        }
    }
    
}
