import Foundation
import MixinServices

class BigAmountConfirmationWindow: AssetConfirmationWindow {
    
    static func instance() -> BigAmountConfirmationWindow {
        return Bundle.main.loadNibNamed("BigAmountConfirmationWindow", owner: nil, options: nil)?.first as! BigAmountConfirmationWindow
    }
    
    func render(asset: AssetItem, user: UserItem, amount: String, memo: String, fiatMoneyAmount: String? = nil, completion: @escaping CompletionHandler) -> BottomSheetView {
        let result = super.render(asset: asset, amount: amount, memo: memo, fiatMoneyAmount: fiatMoneyAmount, completion: completion)
        titleLabel.text = R.string.localizable.large_amount_confirmation()
        tipsLabel.text = R.string.localizable.wallet_transaction_tip(user.fullName, amountExchangeLabel.text ?? "", asset.symbol)
        return result
    }
    
    func render(
        token: MixinTokenItem,
        to user: UserItem,
        amount: Decimal,
        fiatMoneyAmount: Decimal,
        memo: String,
        completion: @escaping CompletionHandler
    ) -> BottomSheetView {
        super.render(token: token, tokenAmount: amount, fiatMoneyAmount: fiatMoneyAmount, memo: memo, completion: completion)
        titleLabel.text = R.string.localizable.large_amount_confirmation()
        tipsLabel.text = R.string.localizable.wallet_transaction_tip(user.fullName, amountExchangeLabel.text ?? "", token.symbol)
        return self
    }
    
}
