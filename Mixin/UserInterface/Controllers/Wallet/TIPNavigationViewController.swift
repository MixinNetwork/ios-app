import UIKit
import MixinServices

class TIPNavigationViewController: LoneBackButtonNavigationController {
    
    enum Destination {
        case wallet
        case transfer(user: UserItem)
        case changePhone
        case setEmergencyContact
    }
    
    private let destination: Destination?
    private let dismissButton = UIButton()
    
    convenience init(intent: TIPIntroViewController.Intent, destination: Destination?) {
        let intro = TIPIntroViewController(intent: intent, interruption: .unknown)
        self.init(intro: intro, destination: destination)
    }
    
    init(intro: TIPIntroViewController, destination: Destination?) {
        self.destination = destination
        super.init(rootViewController: intro)
        modalPresentationStyle = .fullScreen
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dismissButton.tintColor = R.color.icon_tint()
        dismissButton.setImage(R.image.ic_title_close(), for: .normal)
        dismissButton.addTarget(self, action: #selector(dismissAction(sender:)), for: .touchUpInside)
        view.addSubview(dismissButton)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.snp.makeConstraints { (make) in
            make.edges.equalTo(backButton)
        }
    }
    
    @objc func dismissAction(sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    override func updateBackButtonAlpha(animated: Bool) {
        let backButtonAlpha: CGFloat
        let dismissButtonAlpha: CGFloat
        if viewControllers.last is TIPActionViewController {
            backButtonAlpha = 0
            dismissButtonAlpha = 0
        } else if viewControllers.last is TIPIntroViewController {
            backButtonAlpha = 0
            dismissButtonAlpha = 1
        } else {
            backButtonAlpha = 1
            dismissButtonAlpha = 0
        }
        
        func update() {
            backButton.alpha = backButtonAlpha
            dismissButton.alpha = dismissButtonAlpha
        }
        if animated {
            UIView.animate(withDuration: 0.25, animations: update)
        } else {
            update()
        }
    }
    
    func popToFirstInputPINViewController() {
        guard let controller = viewControllers.first(where: { $0 is TIPInputPINViewController }) else {
            return
        }
        popToViewController(controller, animated: true)
    }
    
    func dismissToDestination(animated: Bool) {
        let destination = self.destination
        presentingViewController?.dismiss(animated: animated) {
            guard let navigationController = UIApplication.homeNavigationController else {
                return
            }
            switch destination {
            case .wallet:
                let wallet = R.storyboard.wallet.wallet()!
                navigationController.pushViewController(withBackRoot: wallet)
            case let .transfer(user):
                let transfer = TransferOutViewController.instance(asset: nil, type: .contact(user))
                navigationController.pushViewController(withBackChat: transfer)
            case .changePhone:
                let verify = VerifyPinNavigationController(rootViewController: ChangeNumberVerifyPinViewController())
                navigationController.present(verify, animated: true)
            case .setEmergencyContact:
                let verify = VerifyPinNavigationController(rootViewController: EmergencyContactVerifyPinViewController())
                navigationController.present(verify, animated: true)
            case .none:
                break
            }
        }
    }
    
}
