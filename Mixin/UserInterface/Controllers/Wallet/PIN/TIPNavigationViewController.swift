import UIKit
import MixinServices

final class TIPNavigationViewController: GeneralAppearanceNavigationController {
    
    enum Destination {
        case home
        case wallet
        case transfer(user: UserItem)
        case changePhone
        case setEmergencyContact
    }
    
    private let destination: Destination?
    private let dismissButton = UIButton()
    
    convenience init(intent: TIP.Action, destination: Destination?) {
        Logger.tip.info(category: "TIPNavigation", message: "Init with intent: \(intent), destination: \(String(describing: destination))")
        let intro = TIPIntroViewController(intent: intent)
        self.init(intro: intro, destination: destination)
    }
    
    init(intro: TIPIntroViewController, destination: Destination?) {
        Logger.tip.info(category: "TIPNavigation", message: "Init with arbitrary intro, destination: \(String(describing: destination))")
        self.destination = destination
        super.init(rootViewController: intro)
        modalPresentationStyle = .fullScreen
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    func popToFirstFullscreenInput() {
        guard let controller = viewControllers.first(where: { $0 is TIPFullscreenInputViewController }) else {
            Logger.tip.error(category: "TIPNavigation", message: "No fullscreen input in stack")
            return
        }
        Logger.tip.info(category: "TIPNavigation", message: "Popped to fullscreen input")
        popToViewController(controller, animated: true)
    }
    
    func dismissToDestination(animated: Bool) {
        switch destination {
        case .home:
            AppDelegate.current.mainWindow.rootViewController = HomeContainerViewController()
        case .wallet:
            presentingViewController?.dismiss(animated: animated) {
                if let controller = UIApplication.homeContainerViewController?.homeTabBarController {
                    controller.switchTo(child: .wallet)
                }
            }
        case let .transfer(user):
            presentingViewController?.dismiss(animated: animated) {
                let transfer = TransferOutViewController(token: nil, to: .contact(user))
                UIApplication.homeNavigationController?.pushViewController(withBackChat: transfer)
            }
        case .changePhone:
            presentingViewController?.dismiss(animated: animated) {
                let verify = ChangeNumberPINValidationViewController()
                UIApplication.homeNavigationController?.pushViewController(verify, animated: true)
            }
        case .setEmergencyContact:
            presentingViewController?.dismiss(animated: animated) {
                let verify = RecoveryContactVerifyPINViewController()
                UIApplication.homeNavigationController?.pushViewController(verify, animated: true)
            }
        case .none:
            break
        }
    }
    
}
