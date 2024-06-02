import UIKit

final class Web3DepositViewController: UIViewController {
    
    @IBOutlet weak var qrCodeView: ModernQRCodeView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var decorationImageView: UIImageView!
    
    private let category: Web3Chain.Category
    private let address: String
    
    init(category: Web3Chain.Category, address: String) {
        self.category = category
        self.address = address
        let nib = R.nib.web3DepositView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        qrCodeView.setContent(address, size: qrCodeView.frame.size)
        qrCodeView.setDefaultCornerCurve()
        addressLabel.text = address
        switch category {
        case .evm:
            iconImageView.image = R.image.web3_deposit_evm()!
            descriptionLabel.text = R.string.localizable.web3_deposit_description_evm()
            decorationImageView.image = R.image.web3_deposit_evm_deco()
        case .solana:
            iconImageView.image = R.image.web3_deposit_sol()!
            descriptionLabel.text = R.string.localizable.web3_deposit_description_solana()
            decorationImageView.image = R.image.web3_deposit_sol_deco()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        qrCodeView.setContent(address, size: qrCodeView.frame.size)
    }
    
    @IBAction func copyAddress(_ sender: Any) {
        UIPasteboard.general.string = address
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}
