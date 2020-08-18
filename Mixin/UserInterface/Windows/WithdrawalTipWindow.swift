import UIKit
import MixinServices

class WithdrawalTipWindow: AssetConfirmationWindow {

    func render(asset: AssetItem, completion: @escaping CompletionHandler) -> BottomSheetView {
        self.completion = completion
        assetIconView.setIcon(asset: asset)
        titleLabel.text = Localized.WALLET_WITHDRAWAL_ASSET(assetName: asset.symbol)
        initTimer()
        return self
    }

    class func instance() -> WithdrawalTipWindow {
        return Bundle.main.loadNibNamed("WithdrawalTipWindow", owner: nil, options: nil)?.first as! WithdrawalTipWindow
    }

}
