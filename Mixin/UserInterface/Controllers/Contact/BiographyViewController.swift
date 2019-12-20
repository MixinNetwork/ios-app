import UIKit

class BiographyViewController: AnnouncementViewController {

    private var user: UserItem!

    override var announcement: String {
        return user.biography
    }

    override func saveAction(_ sender: Any) {
        guard !saveButton.isBusy else {
            return
        }
        saveButton.isBusy = true
        AccountAPI.shared.update(biography: newAnnouncement) { [weak self] (result) in
            switch result {
            case let .success(account):
                LoginManager.shared.account = account
                self?.saveSuccessAction()
            case let .failure(error):
                self?.saveFailedAction(error: error)
            }
        }
    }

    class func instance(user: UserItem) -> UIViewController {
        let vc = BiographyViewController()
        vc.user = user
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.profile_edit_biography())
        return container
    }

}
