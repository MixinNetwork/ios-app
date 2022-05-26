import Foundation
import MixinServices

class DuplicateConfirmationWindow: AssetConfirmationWindow {

    func render(traceCreatedAt: String, asset: AssetItem, action: PayWindow.PinAction, amount: String, memo: String, fiatMoneyAmount: String? = nil, completion: @escaping CompletionHandler) -> BottomSheetView {
        let result = super.render(asset: asset, amount: amount, memo: memo, fiatMoneyAmount: fiatMoneyAmount, completion: completion)
        switch action {
        case let .transfer(_, user, _):
            titleLabel.text = R.string.localizable.duplicate_transfer_confirmation()
            tipsLabel.text = R.string.localizable.wallet_transfer_recent_tip(traceCreatedAt.toUTCDate().simpleTimeAgo(), user.fullName, amountLabel.text ?? "")
        case let .withdraw(_, address, _, _):
            titleLabel.text = R.string.localizable.duplicate_transfer_confirmation()
            tipsLabel.text = R.string.localizable.wallet_withdrawal_recent_tip(traceCreatedAt.toUTCDate().simpleTimeAgo(), address.fullAddress.toSimpleKey(), amountLabel.text ?? "")
        default:
            break
        }
        return result
    }

    static func instance() -> DuplicateConfirmationWindow {
        return Bundle.main.loadNibNamed("DuplicateConfirmationWindow", owner: nil, options: nil)?.first as! DuplicateConfirmationWindow
    }
}
