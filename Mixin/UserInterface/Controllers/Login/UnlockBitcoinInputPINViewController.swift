import UIKit
import MixinServices

final class UnlockBitcoinInputPINViewController: FullscreenPINValidationViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
    }
    
    override func continueAction(_ sender: Any) {
        isBusy = true
        let pin = pinField.text
        Task {
            do {
                try await TIP.registerDefaultCommonWalletIfNeeded(pin: pin)
                await MainActor.run {
                    Logger.web3.info(category: "UnlockBitcoinInputPIN", message: "Finished")
                    (navigationController as? UnlockBitcoinNavigationController)?.onSuccess?()
                    navigationController?.presentingViewController?.dismiss(animated: true)
                }
            } catch {
                Logger.web3.error(category: "UnlockBitcoinInputPIN", message: "Failed: \(error)")
                await MainActor.run {
                    self.pinField.clear()
                    self.isBusy = false
                    if let error = error as? MixinAPIError {
                        PINVerificationFailureHandler.handle(error: error) { (description) in
                            self.alert(description)
                        }
                    } else {
                        self.alert(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "unlock_bitcoin"])
    }
    
}
