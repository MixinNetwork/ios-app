import UIKit
import MixinServices

class BiographyViewController: AnnouncementViewController {
    
    private let user: UserItem
    
    override var announcement: String {
        return user.biography
    }
    
    init(user: UserItem) {
        self.user = user
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.edit_biography()
    }
    
    override func saveAction(_ sender: Any) {
        guard !saveButton.isBusy else {
            return
        }
        saveButton.isBusy = true
        AccountAPI.update(biography: newAnnouncement) { [weak self] (result) in
            switch result {
            case let .success(account):
                LoginManager.shared.setAccount(account)
                self?.saveSuccessAction()
            case let .failure(error):
                self?.saveFailedAction(error: error)
            }
        }
    }
    
}
