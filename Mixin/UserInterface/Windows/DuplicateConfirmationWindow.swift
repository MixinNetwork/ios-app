import UIKit
import MixinServices

final class DuplicateConfirmationWindow: AssetConfirmationWindow {
    
    enum Operation {
        case transfer(UserItem)
        case withdraw(WithdrawableAddress)
    }
    
    private let configure: (DuplicateConfirmationWindow) -> Void
    
    init(traceCreatedAt: String, asset: AssetItem, action: PayWindow.PinAction, amount: String, memo: String, fiatMoneyAmount: String? = nil, completion: @escaping CompletionHandler) {
        self.configure = { window in
            window.setup(asset: asset, amount: amount, memo: memo, fiatMoneyAmount: fiatMoneyAmount, completion: completion)
            switch action {
            case let .transfer(_, user, _, _):
                window.titleLabel.text = R.string.localizable.duplicate_transfer_confirmation()
                window.tipsLabel.text = R.string.localizable.wallet_transfer_recent_tip(traceCreatedAt.toUTCDate().simpleTimeAgo(), user.fullName, window.amountLabel.text ?? "")
            default:
                break
            }
        }
        let nib = R.nib.duplicateConfirmationWindow
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    init(
        token: MixinTokenItem,
        operation: Operation,
        amount: Decimal,
        fiatMoneyAmount: Decimal,
        memo: String,
        traceCreatedAt: Date,
        completion: @escaping CompletionHandler
    ) {
        self.configure = { window in
            window.setup(token: token, tokenAmount: amount, fiatMoneyAmount: fiatMoneyAmount, memo: memo, completion: completion)
            switch operation {
            case let .transfer(opponent):
                window.titleLabel.text = R.string.localizable.duplicate_transfer_confirmation()
                window.tipsLabel.text = R.string.localizable.wallet_transfer_recent_tip(traceCreatedAt.simpleTimeAgo(), opponent.fullName, window.amountLabel.text ?? "")
            case let .withdraw(address):
                window.titleLabel.text = R.string.localizable.duplicate_transfer_confirmation()
                window.tipsLabel.text = R.string.localizable.wallet_withdrawal_recent_tip(traceCreatedAt.simpleTimeAgo(), address.compactRepresentation, window.amountLabel.text ?? "")
            }
        }
        let nib = R.nib.duplicateConfirmationWindow
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
