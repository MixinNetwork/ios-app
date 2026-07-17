import UIKit
import MixinServices

final class TIPNavigationController: GeneralAppearanceNavigationController, CheckSessionEnvironmentChild {
    
    private let navigationBarAppearanceUpdater = NavigationBarStyle.AppearanceUpdater()
    
    convenience init(intent: TIP.Action) {
        Logger.tip.info(category: "TIPNavigation", message: "Init with intent: \(intent)")
        let intro = TIPIntroViewController(intent: intent)
        self.init(intro: intro)
    }
    
    init(intro: TIPIntroViewController) {
        Logger.tip.info(category: "TIPNavigation", message: "Init with arbitrary intro")
        super.init(rootViewController: intro)
        modalPresentationStyle = .fullScreen
        delegate = navigationBarAppearanceUpdater
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
    
    func finish(pin: String) {
        Logger.tip.info(category: "TIPNavigation", message: "Finished")
        if isCheckingSessionEnvironment {
            checkSessionEnvironmentAgain(
                freshAccount: LoginManager.shared.account,
                pin: pin,
            )
        } else {
            presentingViewController?.dismiss(animated: true)
        }
    }
    
}
