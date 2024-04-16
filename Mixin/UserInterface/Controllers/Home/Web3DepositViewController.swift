import UIKit

final class Web3DepositViewController: UIViewController {
    
    @IBOutlet weak var qrCodeView: ModernQRCodeView!
    @IBOutlet weak var addressLabel: UILabel!
    
    private let address: String
    
    init(address: String) {
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
