import UIKit
import MixinServices

class AddWalletInputOnChainInfoViewController: InputOnChainInfoViewController {
    
    private(set) var importedAddresses: Set<String>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.global().async {
            let destinations = Web3AddressDAO.shared.allDestinations()
            DispatchQueue.main.async {
                self.importedAddresses = destinations
                self.detectInput()
            }
        }
    }
    
}
