import UIKit
import MixinServices

class WithdrawalTipWindow: AssetConfirmationWindow {
    
    class func instance() -> WithdrawalTipWindow {
        return Bundle.main.loadNibNamed("WithdrawalTipWindow", owner: nil, options: nil)?.first as! WithdrawalTipWindow
    }
    
    func render(asset: AssetItem, completion: @escaping CompletionHandler) -> BottomSheetView {
        self.completion = completion
        assetIconView.setIcon(asset: asset)
        titleLabel.text = R.string.localizable.symbol_withdrawal(asset.symbol)
        return self
    }
    
    func render(token: TokenItem, completion: @escaping CompletionHandler) -> BottomSheetView {
        self.completion = completion
        assetIconView.setIcon(token: token)
        titleLabel.text = R.string.localizable.symbol_withdrawal(token.symbol)
        return self
    }
    
}
