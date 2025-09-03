import UIKit
import MixinServices

final class DepositAddressSummaryView: UIView {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    @IBOutlet weak var qrCodeView: ModernQRCodeView!
    @IBOutlet weak var tokenBackgroundView: UIView!
    @IBOutlet weak var tokenIconView: BadgeIconView!
    
    @IBOutlet weak var footerStackView: UIStackView!
    
    @IBOutlet weak var qrCodeDimensionConstraint: NSLayoutConstraint!
    @IBOutlet weak var tokenBackgroundDimensionConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        qrCodeView.setDefaultCornerCurve()
        tokenBackgroundView.layer.cornerRadius = tokenBackgroundDimensionConstraint.constant / 2
        tokenBackgroundView.layer.masksToBounds = true
    }
    
    func load(token: any Token, address: String, network: String?, minimumDeposit: String?) {
        titleLabel.text = R.string.localizable.deposit_token_to_mixin(token.symbol)
        descriptionLabel.text = R.string.localizable.scan_qr_code_to_send_token(token.symbol)
        let qrCodeSize = CGSize(
            width: qrCodeDimensionConstraint.constant,
            height: qrCodeDimensionConstraint.constant
        )
        qrCodeView.setContent(address, size: qrCodeSize)
        tokenIconView.setIcon(
            token: token,
            chain: (token as? OnChainToken)?.chain
        )
        for view in footerStackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        
        func makeTitleLabel() -> UILabel {
            let label = UILabel()
            label.font = .systemFont(ofSize: 12)
            label.textColor = R.color.text_quaternary()
            return label
        }
        
        func makeContentLabel() -> UILabel {
            let label = UILabel()
            label.font = .systemFont(ofSize: 14)
            label.textColor = R.color.text()
            return label
        }
        
        let addressTitleLabel = makeTitleLabel()
        addressTitleLabel.text = R.string.localizable.address()
        let addressContentLabel = makeContentLabel()
        addressContentLabel.text = address
        addressContentLabel.numberOfLines = 0
        let addressStackView = UIStackView(
            arrangedSubviews: [addressTitleLabel, addressContentLabel]
        )
        addressStackView.axis = .vertical
        addressStackView.spacing = 6
        footerStackView.addArrangedSubview(addressStackView)
        
        let infoStackView = UIStackView()
        if let network {
            let networkTitleLabel = makeTitleLabel()
            networkTitleLabel.text = R.string.localizable.network()
            let networkContentLabel = makeContentLabel()
            networkContentLabel.text = network
            let networkStackView = UIStackView(
                arrangedSubviews: [networkTitleLabel, networkContentLabel]
            )
            networkStackView.axis = .vertical
            networkStackView.spacing = 6
            infoStackView.addArrangedSubview(networkStackView)
        }
        if let minimumDeposit {
            let minimumDepositTitleLabel = makeTitleLabel()
            minimumDepositTitleLabel.text = R.string.localizable.minimum_deposit()
            minimumDepositTitleLabel.textAlignment = .right
            let minimumDepositContentLabel = makeContentLabel()
            minimumDepositContentLabel.text = minimumDeposit
            minimumDepositContentLabel.textAlignment = .right
            let minimumDepositStackView = UIStackView(
                arrangedSubviews: [minimumDepositTitleLabel, minimumDepositContentLabel]
            )
            minimumDepositStackView.axis = .vertical
            minimumDepositStackView.spacing = 6
            infoStackView.addArrangedSubview(minimumDepositStackView)
        }
        if !infoStackView.arrangedSubviews.isEmpty {
            infoStackView.axis = .horizontal
            infoStackView.distribution = .equalSpacing
            footerStackView.addArrangedSubview(infoStackView)
        }
    }
    
}
