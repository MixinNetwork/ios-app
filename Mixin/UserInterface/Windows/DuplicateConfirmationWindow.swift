import Foundation
import MixinServices

class DuplicateConfirmationWindow: AssetConfirmationWindow {
    
    enum Operation {
        case transfer(UserItem)
        case withdraw(Address)
    }
    
    static func instance() -> DuplicateConfirmationWindow {
        return Bundle.main.loadNibNamed("DuplicateConfirmationWindow", owner: nil, options: nil)?.first as! DuplicateConfirmationWindow
    }
    
    func render(traceCreatedAt: String, asset: AssetItem, action: PayWindow.PinAction, amount: String, memo: String, fiatMoneyAmount: String? = nil, completion: @escaping CompletionHandler) -> BottomSheetView {
        let result = super.render(asset: asset, amount: amount, memo: memo, fiatMoneyAmount: fiatMoneyAmount, completion: completion)
        switch action {
        case let .transfer(_, user, _, _):
            titleLabel.text = R.string.localizable.duplicate_transfer_confirmation()
            tipsLabel.text = R.string.localizable.wallet_transfer_recent_tip(traceCreatedAt.toUTCDate().simpleTimeAgo(), user.fullName, amountLabel.text ?? "")
        case let .withdraw(_, address, _, _):
            titleLabel.text = R.string.localizable.duplicate_transfer_confirmation()
            tipsLabel.text = R.string.localizable.wallet_withdrawal_recent_tip(traceCreatedAt.toUTCDate().simpleTimeAgo(), address.compactRepresentation, amountLabel.text ?? "")
        default:
            break
        }
        return result
    }
    
    func render(
        token: TokenItem,
        operation: Operation,
        amount: Decimal,
        fiatMoneyAmount: Decimal,
        memo: String,
        traceCreatedAt: Date,
        completion: @escaping CompletionHandler
    ) -> BottomSheetView {
        super.render(token: token, tokenAmount: amount, fiatMoneyAmount: fiatMoneyAmount, memo: memo, completion: completion)
        switch operation {
        case let .transfer(opponent):
            titleLabel.text = R.string.localizable.duplicate_transfer_confirmation()
            tipsLabel.text = R.string.localizable.wallet_transfer_recent_tip(traceCreatedAt.simpleTimeAgo(), opponent.fullName, amountLabel.text ?? "")
        case let .withdraw(address):
            titleLabel.text = R.string.localizable.duplicate_transfer_confirmation()
            tipsLabel.text = R.string.localizable.wallet_withdrawal_recent_tip(traceCreatedAt.simpleTimeAgo(), address.compactRepresentation, amountLabel.text ?? "")
        }
        return self
    }
    
}
