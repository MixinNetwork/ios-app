import UIKit

class ShowEmergencyContactValidationViewController: PinValidationViewController {
    
    convenience init() {
        self.init(nib: R.nib.pinValidationView)
        transitioningDelegate = presentationManager
        modalPresentationStyle = .custom
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        descriptionLabel.text = R.string.localizable.emergency_pin_protection_hint()
    }
    
    override func validate(pin: String) {
        EmergencyAPI.shared.show(pin: pin) { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.loadingIndicator.stopAnimating()
            switch result {
            case .success(let user):
                weakSelf.dismiss(animated: true, completion: {
                    let userWindow = UserWindow.instance()
                    let item = UserItem.createUser(userId: user.userId,
                                                   fullName: user.fullName ?? "",
                                                   identityNumber: user.identityNumber,
                                                   avatarUrl: user.avatarUrl ?? "",
                                                   appId: user.appId)
                    userWindow.updateUser(user: item)
                    userWindow.presentView()
                })
            case .failure(let error):
                weakSelf.handle(error: error)
            }
        }
    }
    
}
