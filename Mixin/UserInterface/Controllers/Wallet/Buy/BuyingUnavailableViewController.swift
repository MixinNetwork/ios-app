import UIKit
import IdensicMobileSDK
import MixinServices

class BuyingUnavailableViewController: IntroViewController {
    
    enum State {
        case unavailableRegion
        case kycPending
        case kycRetry
        case kycBlocked
    }
    
    private let state: State
    
    init(state: State) {
        self.state = state
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch state {
        case .unavailableRegion:
            iconImageView.image = R.image.wallet.unavailable_region()
            titleLabel.text = R.string.localizable.coming_soon_to_your_region()
            descriptionTextLabel.text = R.string.localizable.buying_unavailable_description()
            noticeTextView.isHidden = true
            nextButton.setTitle(R.string.localizable.ok(), for: .normal)
            actionDescriptionLabel.isHidden = true
        case .kycPending:
            iconImageView.image = R.image.wallet.kyc_pending()
            titleLabel.text = R.string.localizable.identity_verifying()
            descriptionTextLabel.text = R.string.localizable.identity_verification_description()
            noticeTextView.isHidden = true
            nextButton.setTitle(R.string.localizable.ok(), for: .normal)
            actionDescriptionLabel.isHidden = true
        case .kycRetry:
            iconImageView.image = R.image.wallet.ic_price_expired()
            titleLabel.text = R.string.localizable.verification_failed()
            descriptionTextLabel.text = R.string.localizable.verification_failed_description()
            noticeTextView.isHidden = true
            nextButton.setTitle(R.string.localizable.continue(), for: .normal)
            actionDescriptionLabel.isHidden = true
        case .kycBlocked:
            iconImageView.image = R.image.wallet.ic_price_expired()
            titleLabel.text = R.string.localizable.verification_failed()
            descriptionTextLabel.text = R.string.localizable.verification_blocked_description()
            noticeTextView.textColor = .mixinRed
            noticeTextView.textContainerInset = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
            noticeTextView.isHidden = true
            nextButton.setTitle(R.string.localizable.chat_with_us(), for: .normal)
            actionDescriptionLabel.isHidden = true
        }
    }
    
    override func continueToNext(_ sender: RoundedButton) {
        switch state {
        case .unavailableRegion, .kycPending:
            presentingViewController?.dismiss(animated: true)
        case .kycRetry:
            guard let navigationController else {
                return
            }
            let sdk = SNSMobileSDK(accessToken: "")
            guard sdk.isReady else {
                alert(R.string.localizable.sumsub_not_ready(), message: sdk.verboseStatus)
                return
            }
            sdk.setTokenExpirationHandler { onComplete in
                RouteAPI.sumsubToken() { result in
                    switch result {
                    case let .success(token):
                        onComplete(token)
                    case .failure:
                        onComplete(nil)
                    }
                }
            }
            navigationController.present(sdk.mainVC, animated: true) {
                navigationController.popViewController(animated: false)
            }
        case .kycBlocked:
            guard let presentingViewController = self.presentingViewController else {
                return
            }
            presentingViewController.dismiss(animated: true, completion: {
                guard let navigationController = UIApplication.homeNavigationController else {
                    return
                }
                guard let user = UserDAO.shared.getUser(identityNumber: "7000") else {
                    return
                }
                var viewControllers = navigationController.viewControllers
                if let homeIndex = viewControllers.firstIndex(where: { $0 is HomeViewController }) {
                    viewControllers.removeLast(viewControllers.count - homeIndex - 1)
                }
                let conversation = ConversationViewController.instance(ownerUser: user)
                viewControllers.append(conversation)
                navigationController.setViewControllers(viewControllers, animated: true)
            })
        }
    }
    
}

extension BuyingUnavailableViewController: ContainerViewControllerDelegate {
    
    func barLeftButtonTappedAction() {
        switch state {
        case .unavailableRegion, .kycPending, .kycBlocked:
            presentingViewController?.dismiss(animated: true)
        case .kycRetry:
            navigationController?.popViewController(animated: true)
        }
    }
    
    func imageBarLeftButton() -> UIImage? {
        switch state {
        case .unavailableRegion, .kycPending, .kycBlocked:
            return R.image.ic_title_close()
        case .kycRetry:
            return R.image.ic_title_back()
        }
    }
    
}
