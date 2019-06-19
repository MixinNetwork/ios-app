import Foundation

class EmergencyWindow: BottomSheetView {
    
    class func instance() -> EmergencyWindow {
        return Bundle.main.loadNibNamed("EmergencyWindow", owner: nil, options: nil)?.first as! EmergencyWindow
    }
    
    @IBAction func nextAction(_ sender: Any) {
        dismissPopupControllerAnimated()
        if let account = AccountAPI.shared.account, account.has_pin {
            let vc = EmergencyContactVerifyPinViewController()
            let navigationController = VerifyPinNavigationController(rootViewController: vc)
            UIApplication.rootNavigationController()?.present(navigationController, animated: true, completion: nil)
        } else {
            let vc = WalletPasswordViewController.instance(dismissTarget: .setEmergencyContact)
            UIApplication.rootNavigationController()?.pushViewController(vc, animated: true)
        }
    }
    
}
