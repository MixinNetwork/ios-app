import UIKit

final class UnlockCommonWalletChainsNavigationController: UINavigationController, UIAdaptivePresentationControllerDelegate {
    
    var onSuccess: (() -> Void)?
    
    init(content: UnlockableCommonWalletChain) {
        let unlock = UnlockCommonWalletChainsViewController(content: content)
        super.init(rootViewController: unlock)
        presentationController?.delegate = self
        setNavigationBarHidden(true, animated: false)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        false
    }
    
}
