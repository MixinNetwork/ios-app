import UIKit
import MixinServices

final class BigAmountConfirmationWindow: AssetConfirmationWindow {
    
    private let configure: (BigAmountConfirmationWindow) -> Void
    
    init(asset: AssetItem, user: UserItem, amount: String, memo: String, fiatMoneyAmount: String? = nil, completion: @escaping CompletionHandler) {
        self.configure = { window in
            window.setup(asset: asset, amount: amount, memo: memo, fiatMoneyAmount: fiatMoneyAmount, completion: completion)
            window.titleLabel.text = R.string.localizable.large_amount_confirmation()
            window.tipsLabel.text = R.string.localizable.wallet_transaction_tip(user.fullName, window.amountExchangeLabel.text ?? "", asset.symbol)
        }
        let nib = R.nib.bigAmountConfirmationWindow
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    init(
        token: MixinTokenItem,
        to user: UserItem,
        amount: Decimal,
        fiatMoneyAmount: Decimal,
        memo: String,
        completion: @escaping CompletionHandler
    ) {
        self.configure = { window in
            window.setup(token: token, tokenAmount: amount, fiatMoneyAmount: fiatMoneyAmount, memo: memo, completion: completion)
            window.titleLabel.text = R.string.localizable.large_amount_confirmation()
            window.tipsLabel.text = R.string.localizable.wallet_transaction_tip(user.fullName, window.amountExchangeLabel.text ?? "", token.symbol)
        }
        let nib = R.nib.bigAmountConfirmationWindow
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configure(self)
    }
    
}
