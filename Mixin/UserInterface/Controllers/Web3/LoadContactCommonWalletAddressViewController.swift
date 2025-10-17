import UIKit
import MixinServices

final class LoadContactCommonWalletAddressViewController: IntroductionViewController {
    
    private let payment: Web3SendingTokenPayment
    private let user: UserItem
    private let chainID: String
    private let busyIndicator = ActivityIndicatorView()
    
    private var didPerformInitialLoading = false
    
    private weak var errorDescriptionLabel: UILabel?
    
    init(payment: Web3SendingTokenPayment, user: UserItem, chainID: String) {
        self.payment = payment
        self.user = user
        self.chainID = chainID
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageViewTopConstraint.constant = switch ScreenHeight.current {
        case .short:
            40
        case .medium:
            80
        case .long, .extraLong:
            120
        }
        imageView.image = R.image.mnemonic_login()
        
        titleLabel.text = R.string.localizable.fetching_address()
        contentLabelTopConstraint.constant = 20
        contentLabel.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        contentLabel.adjustsFontForContentSizeCategory = true
        contentLabel.textAlignment = .center
        
        busyIndicator.tintColor = R.color.outline_primary()
        actionStackView.addArrangedSubview(busyIndicator)
        busyIndicator.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
        showLoading()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !didPerformInitialLoading {
            didPerformInitialLoading = true
            fetchAddress(user: user, chainID: chainID)
        }
    }
    
    @objc private func retry(_ sender: Any) {
        showLoading()
        fetchAddress(user: user, chainID: chainID)
    }
    
    @objc private func giveUp(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    private func showLoading() {
        busyIndicator.startAnimating()
        actionButton.isHidden = true
        contentLabel.textColor = R.color.text_tertiary()
        contentLabel.text = R.string.localizable.mnemonic_phrase_take_long()
        contentLabel.isHidden = false
        errorDescriptionLabel?.removeFromSuperview()
    }
    
    private func showNotFound() {
        imageView.image = R.image.add_wallet_error()
        titleLabel.text = R.string.localizable.fetching_address_failed()
        busyIndicator.stopAnimating()
        actionButton.style = .filled
        actionButton.setTitle(R.string.localizable.ok(), for: .normal)
        actionButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        actionButton.removeTarget(self, action: nil, for: .allEvents)
        actionButton.addTarget(self, action: #selector(giveUp(_:)), for: .touchUpInside)
        actionButton.isHidden = false
        contentLabel.textColor = R.color.error_red()
        contentLabel.text = R.string.localizable.fetching_address_failed_reason()
        contentLabel.isHidden = false
    }
    
    private func showError(_ description: String) {
        busyIndicator.stopAnimating()
        actionButton.style = .filled
        actionButton.setTitle(R.string.localizable.retry(), for: .normal)
        actionButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        actionButton.removeTarget(self, action: nil, for: .allEvents)
        actionButton.addTarget(self, action: #selector(retry(_:)), for: .touchUpInside)
        actionButton.isHidden = false
        let errorDescriptionLabel = UILabel()
        errorDescriptionLabel.textColor = R.color.error_red()
        errorDescriptionLabel.numberOfLines = 0
        errorDescriptionLabel.textAlignment = .center
        errorDescriptionLabel.font = .preferredFont(forTextStyle: .caption1)
        errorDescriptionLabel.adjustsFontForContentSizeCategory = true
        errorDescriptionLabel.text = description
        actionStackView.addArrangedSubview(errorDescriptionLabel)
        errorDescriptionLabel.snp.makeConstraints { make in
            make.width.equalTo(233)
        }
        self.errorDescriptionLabel = errorDescriptionLabel
    }
    
    private func fetchAddress(user: UserItem, chainID: String) {
        RouteAPI.userAddressDestination(
            userID: user.userId,
            chainID: chainID
        ) { [payment, weak self] result in
            switch result {
            case .success(let address):
                let addressPayment = Web3SendingTokenToAddressPayment(
                    payment: payment,
                    toAddress: address,
                    toAddressLabel: .contact(user)
                )
                let inputAmount = Web3TransferInputAmountViewController(payment: addressPayment)
                self?.navigationController?.pushViewController(replacingCurrent: inputAmount, animated: true)
            case .failure(.response(.notFound)):
                self?.showNotFound()
            case .failure(let error):
                self?.showError(error.localizedDescription)
            }
        }
    }
    
}
