import UIKit
import MixinServices

class LegacyAddressWindow: BottomSheetView {

    @IBOutlet weak var containerView: UIView!

    private let addressView = LegacyAddressView.instance()

    override func awakeFromNib() {
        super.awakeFromNib()
        containerView.addSubview(addressView)
        addressView.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
    }

    override func dismissPopupController(animated: Bool) {
        if addressView.processing {
            return
        }
        addressView.dismissCallback?(false)
        addressView.dismissCallback = nil
        super.dismissPopupController(animated: animated)
    }

    func presentPopupControllerAnimated(action: LegacyAddressView.action, asset: AssetItem, addressRequest: AddressRequest?, address: Address?, dismissCallback: ((Bool) -> Void)?) {
        guard !isShowing else {
            return
        }

        super.presentPopupControllerAnimated()
        addressView.render(action: action, asset: asset, addressRequest: addressRequest, address: address, dismissCallback: dismissCallback, superView: self)
    }

    class func instance() -> LegacyAddressWindow {
        R.nib.legacyAddressWindow(withOwner: nil)!
    }
}

