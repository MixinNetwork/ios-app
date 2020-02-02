import UIKit
import MixinServices

class AddressWindow: BottomSheetView {

    @IBOutlet weak var containerView: UIView!

    private let addressView = AddressView.instance()

    override func awakeFromNib() {
        super.awakeFromNib()
        containerView.addSubview(addressView)
        addressView.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
    }

    override func dismissPopupControllerAnimated() {
        if addressView.processing {
            return
        }
        addressView.dismissCallback?(false)
        super.dismissPopupControllerAnimated()
    }

    func presentPopupControllerAnimated(action: AddressView.action, asset: AssetItem, addressRequest: AddressRequest?, address: Address?, dismissCallback: ((Bool) -> Void)?) {
        guard !isShowing else {
            return
        }

        super.presentPopupControllerAnimated()
        addressView.render(action: action, asset: asset, addressRequest: addressRequest, address: address, dismissCallback: dismissCallback, superView: self)
    }

    class func instance() -> AddressWindow {
        return Bundle.main.loadNibNamed("AddressWindow", owner: nil, options: nil)?.first as! AddressWindow
    }
}

