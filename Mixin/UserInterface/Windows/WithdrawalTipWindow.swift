import UIKit
import MixinServices

class WithdrawalTipWindow: AssetConfirmationWindow {
    
    class func instance() -> WithdrawalTipWindow {
        return Bundle.main.loadNibNamed("WithdrawalTipWindow", owner: nil, options: nil)?.first as! WithdrawalTipWindow
    }
    
    func render(asset: AssetItem, completion: @escaping CompletionHandler) -> BottomSheetView {
        self.completion = completion
        assetIconView.setIcon(asset: asset)
        titleLabel.text = R.string.localizable.wallet_withdrawal_asset(asset.symbol)
        return self
    }
    
}
