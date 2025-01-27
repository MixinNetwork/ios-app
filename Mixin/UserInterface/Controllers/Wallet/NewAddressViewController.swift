import UIKit
import MixinServices

final class NewAddressViewController: AddressInfoInputViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.address()
    }
    
    override func goNext(_ sender: Any) {
        
    }
    
}
