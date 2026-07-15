import UIKit
import MixinServices

final class CreateAccountIntroductionViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var featureStackView: UIStackView!
    @IBOutlet weak var actionStackView: UIStackView!
    @IBOutlet weak var createAccountButton: UIButton!
    @IBOutlet weak var importWalletButton: UIButton!
    @IBOutlet weak var footerTextView: IntroTextView!
    
    private let analyticSource: String
    
    init(analyticSource: String) {
        self.analyticSource = analyticSource
        let nib = R.nib.createAccountIntroductionView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.create_your_account()
        let featureViews = [
            FeatureItemView(
                image: R.image.feature_decentralize()!,
                title: R.string.localizable.feature_truly_decentralized(),
                description: R.string.localizable.feature_truly_decentralized_description(),
            ),
            FeatureItemView(
                image: R.image.feature_privacy_by_default()!,
                title: R.string.localizable.feature_privacy_by_default(),
                description: R.string.localizable.feature_privacy_by_default_description(),
            ),
            FeatureItemView(
                image: R.image.feature_all_in_one()!,
                title: R.string.localizable.feature_all_in_one(),
                description: R.string.localizable.feature_all_in_one_description(),
            ),
        ]
        featureViews.forEach(featureStackView.addArrangedSubview(_:))
        actionStackView.setCustomSpacing(16, after: createAccountButton)
        createAccountButton.configuration?.attributedTitle = AttributedString(
            string: R.string.localizable.create_an_account(),
            scalingByFontSize: 16,
            weight: .medium
        )
        importWalletButton.configuration?.attributedTitle = AttributedString(
            string: R.string.localizable.import_from_another_wallet(),
            scalingByFontSize: 16,
            weight: .medium
        )
        footerTextView.attributedText = .agreement()
    }
    
    @IBAction func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @IBAction func createAccount(_ sender: Any) {
        guard let presentingViewController else {
            return
        }
        let navigationController = presentingViewController.navigationController
        ?? (presentingViewController as? UINavigationController)
        guard let navigationController else {
            return
        }
        presentingViewController.dismiss(animated: true) { [analyticSource] in
            let mnemonics: MixinMnemonics? = if let entropy = AppGroupKeychain.mnemonics {
                try? MixinMnemonics(entropy: entropy)
            } else {
                nil
            }
            let next = LoginWithMnemonicViewController(action: .signUp(mnemonics))
            var viewControllers = navigationController.viewControllers.filter { controller in
                controller is OnboardingViewController
            }
            viewControllers.append(next)
            navigationController.setViewControllers(viewControllers, animated: true)
            Logger.login.info(category: "CreateAccountIntro", message: "Sign Up")
            reporter.report(event: .signUpStart, tags: ["source": analyticSource])
        }
    }
    
    @IBAction func importWallet(_ sender: Any) {
        guard let presentingViewController else {
            return
        }
        let navigationController = presentingViewController.navigationController
        ?? (presentingViewController as? UINavigationController)
        guard let navigationController else {
            return
        }
        presentingViewController.dismiss(animated: true) {
            let next = SignInWithBIP39MnemonicsViewController()
            var viewControllers = navigationController.viewControllers.filter { controller in
                controller is OnboardingViewController
            }
            viewControllers.append(next)
            navigationController.setViewControllers(viewControllers, animated: true)
            Logger.login.info(category: "CreateAccountIntro", message: "Import Wallet")
        }
    }
    
}
