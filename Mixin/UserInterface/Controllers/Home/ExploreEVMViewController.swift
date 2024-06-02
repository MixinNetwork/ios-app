import UIKit
import MixinServices

final class ExploreEVMViewController: ExploreWeb3ViewController {
    
    init() {
        super.init(category: .evm)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(propertiesDidUpdate(_:)), name: PropertiesDAO.propertyDidUpdateNotification, object: nil)
        let address: String? = PropertiesDAO.shared.unsafeValue(forKey: .evmAddress)
        reloadData(address: address)
    }
    
    override func unlockAccount(_ sender: Any) {
        let unlock = UnlockEVMAccountViewController()
        present(unlock, animated: true)
    }
    
    @objc private func propertiesDidUpdate(_ notification: Notification) {
        guard let change = notification.userInfo?[PropertiesDAO.Key.evmAddress] as? PropertiesDAO.Change else {
            return
        }
        switch change {
        case .removed:
            reloadData(address: nil)
        case .saved(let convertibleAddress):
            let address = String(convertibleAddress)
            reloadData(address: address)
        }
    }
    
}
