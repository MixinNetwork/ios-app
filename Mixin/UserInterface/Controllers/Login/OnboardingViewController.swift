import UIKit
import MixinServices

final class OnboardingViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var signUpButton: StyledButton!
    @IBOutlet weak var signInButton: StyledButton!
    @IBOutlet weak var versionLabel: UILabel!
    
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var actionsBottomConstraint: NSLayoutConstraint!
    
    init() {
        Logger.redirectTIPLogsToLogin = true
        let nib = R.nib.onboardingView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch ScreenHeight.current {
        case .short:
            imageViewTopConstraint.constant = 0
            actionsBottomConstraint.constant = 8
        case .medium:
            imageViewTopConstraint.constant = 20
            actionsBottomConstraint.constant = 16
        case .long, .extraLong:
            imageViewTopConstraint.constant = 40
            actionsBottomConstraint.constant = 38
        }
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 24, weight: .semibold), adjustForContentSize: true)
        descriptionLabel.text = R.string.localizable.onboarding_description()
        signUpButton.setTitle(R.string.localizable.create_account(), for: .normal)
        signUpButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        signUpButton.style = .filled
        signInButton.setTitle(R.string.localizable.landing_have_account(), for: .normal)
        signInButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        signInButton.style = .tinted
        versionLabel.text = R.string.localizable.current_version(Bundle.main.fullVersion)
        Logger.login.info(category: "Onboarding", message: "App \(Bundle.main.fullVersion) onboards, device: \(Device.current.machineName) \(ProcessInfo.processInfo.operatingSystemVersionString), id: \(Device.current.id)")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    @IBAction func signUp(_ sender: Any) {
        let signup = SignUpViewController()
        navigationController?.pushViewController(signup, animated: true)
        Logger.login.info(category: "Onboarding", message: "Sign up")
    }
    
    @IBAction func signIn(_ sender: Any) {
        let mobileNumber = SignInWithMobileNumberViewController()
        navigationController?.pushViewController(mobileNumber, animated: true)
        Logger.login.info(category: "Onboarding", message: "Sign in")
        reporter.report(event: .loginStart)
    }
    
}
