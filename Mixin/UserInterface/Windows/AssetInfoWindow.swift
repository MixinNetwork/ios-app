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

    func presentWindow(asset: AssetItem) {
        self.asset = asset
        assetView.setIcon(asset: asset)
        nameLabel.text = asset.name
        symbolLabel.text = asset.symbol
        chainLabel.text = asset.chain?.name
        if !asset.assetKey.isEmpty {
            contractLabel.text = asset.assetKey
            contractView.isHidden = false
        } else {
            contractView.isHidden = true
        }
        presentPopupControllerAnimated()
    }

    @IBAction func dismissAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }

    class func instance() -> AssetInfoWindow {
        return Bundle.main.loadNibNamed("AssetInfoWindow", owner: nil, options: nil)?.first as! AssetInfoWindow
    }

}
