import UIKit

final class UnlockBitcoinNavigationController: UINavigationController, UIAdaptivePresentationControllerDelegate {
    
    var onSuccess: (() -> Void)?
    
    init() {
        let unlock = UnlockBitcoinViewController()
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
