import UIKit
import MixinServices

final class Web3TokenViewController: UIViewController {
    
    private let address: String
    private let token: Web3Token
    
    init(address: String, token: Web3Token) {
        self.address = address
        self.token = token
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Web3API.transactions(address: address, chainID: token.chainID, fungibleID: token.fungibleID) { result in
            switch result {
            case .success(let transactions):
                break
            case .failure(let error):
                print(error)
            }
        }
    }
    
}
