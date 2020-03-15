import UIKit
import MixinServices

class AssetInfoWindow: BottomSheetView {

    @IBOutlet weak var assetView: AssetIconView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var chainLabel: UILabel!
    @IBOutlet weak var contractLabel: UILabel!
    @IBOutlet weak var contractView: UIView!
    
    private var asset: AssetItem!

    override func awakeFromNib() {
        super.awakeFromNib()
        contractLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyAction)))
    }

    func presentWindow(asset: AssetItem) {
        self.asset = asset
        assetView.setIcon(asset: asset)
        nameLabel.text = asset.name
        symbolLabel.text = asset.symbol
        chainLabel.text = asset.chainName
        if !asset.assetKey.isEmpty {
            contractLabel.text = asset.assetKey
            contractView.isHidden = false
        } else {
            contractView.isHidden = true
        }
        presentPopupControllerAnimated()
    }

    @objc func copyAction() {
        guard asset != nil else {
            return
        }

        let assetKey = asset.assetKey
        let alc = UIAlertController(title: R.string.localizable.wallet_asset_key(), message: R.string.localizable.wallet_asset_key_copy_tips(), preferredStyle: .alert)
        alc.addAction(UIAlertAction(title: R.string.localizable.action_copy(), style: .cancel, handler: { (_) in
            UIPasteboard.general.string = assetKey
            showAutoHiddenHud(style: .notification, text: Localized.TOAST_COPIED)
        }))
        UIApplication.currentActivity()?.present(alc, animated: true, completion: nil)
    }

    @IBAction func dismissAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }

    class func instance() -> AssetInfoWindow {
        return Bundle.main.loadNibNamed("AssetInfoWindow", owner: nil, options: nil)?.first as! AssetInfoWindow
    }

}
