import UIKit
import MixinServices

final class ExploreViewController: UIViewController {
    
    @IBOutlet weak var segmentStackView: UIStackView!
    @IBOutlet weak var contentContainerView: UIView!
    
    private let favoriteViewController = ExploreFavoriteViewController()
    private let allAppsViewController = ExploreAllAppsViewController()
    private let hiddenSearchTopMargin: CGFloat = -28
    
    private var favoriteSegmentButton: UIButton!
    private var botsSegmentButton: UIButton!
    
    private weak var searchViewController: ExploreSearchViewController?
    private weak var searchViewCenterYConstraint: NSLayoutConstraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        favoriteSegmentButton = addSegment(title: R.string.localizable.favorite(), action: #selector(switchToFavorite(_:)))
        botsSegmentButton = addSegment(title: R.string.localizable.bots_title(), action: #selector(switchToAll(_:)))
        addContentViewController(allAppsViewController)
        addContentViewController(favoriteViewController)
        switchToFavorite(self)
    }
    
    @IBAction func searchApps(_ sender: Any) {
        let searchViewController = ExploreSearchViewController(users: allAppsViewController.allUsers)
        addChild(searchViewController)
        searchViewController.view.alpha = 0
        view.addSubview(searchViewController.view)
        searchViewController.view.snp.makeConstraints { make in
            make.size.centerX.equalToSuperview()
        }
        let searchViewCenterYConstraint = searchViewController.view.centerYAnchor
            .constraint(equalTo: view.centerYAnchor, constant: hiddenSearchTopMargin)
        searchViewCenterYConstraint.isActive = true
        searchViewController.didMove(toParent: self)
        view.layoutIfNeeded()
        searchViewCenterYConstraint.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
            searchViewController.view.alpha = 1
        }
        self.searchViewController = searchViewController
        self.searchViewCenterYConstraint = searchViewCenterYConstraint
    }
    
    @IBAction func scanQRCode(_ sender: Any) {
        UIApplication.homeNavigationController?.pushCameraViewController(asQRCodeScanner: true)
    }
    
    @IBAction func openSettings(_ sender: Any) {
        let settings = SettingsViewController.instance()
        navigationController?.pushViewController(settings, animated: true)
    }
    
    func perform(action: ExploreAction) {
        switch action {
        case .camera:
            UIApplication.homeNavigationController?.pushCameraViewController(asQRCodeScanner: false)
        case .linkDesktop:
            let desktop = DesktopViewController.instance()
            navigationController?.pushViewController(desktop, animated: true)
        case .customerService:
            if let user = UserDAO.shared.getUser(identityNumber: "7000") {
                let conversation = ConversationViewController.instance(ownerUser: user)
                navigationController?.pushViewController(conversation, animated: true)
            }
        case .editFavoriteApps:
            let editApps = EditFavoriteAppsViewController.instance()
            navigationController?.pushViewController(editApps, animated: true)
        }
    }
    
    func presentProfile(user: User) {
        let item = UserItem.createUser(from: user)
        let profile = UserProfileViewController(user: item)
        present(profile, animated: true, completion: nil)
    }
    
    func cancelSearching() {
        guard let searchViewController, let searchViewCenterYConstraint else {
            return
        }
        searchViewCenterYConstraint.constant = hiddenSearchTopMargin
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
            searchViewController.view.alpha = 0
        } completion: { _ in
            searchViewController.willMove(toParent: nil)
            searchViewController.view.removeFromSuperview()
            searchViewController.removeFromParent()
        }
    }
    
}

extension ExploreViewController {
    
    @objc private func switchToFavorite(_ sender: Any) {
        setSegmentButton(favoriteSegmentButton, isSelected: true)
        setSegmentButton(botsSegmentButton, isSelected: false)
        contentContainerView.bringSubviewToFront(favoriteViewController.view)
    }
    
    @objc private func switchToAll(_ sender: Any) {
        setSegmentButton(favoriteSegmentButton, isSelected: false)
        setSegmentButton(botsSegmentButton, isSelected: true)
        contentContainerView.bringSubviewToFront(allAppsViewController.view)
    }
    
    private func addSegment(title: String, action: Selector) -> UIButton {
        let button = UIButton()
        button.setTitle(title, for: .normal)
        button.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        button.layer.borderWidth = 1
        button.layer.cornerRadius = 19
        button.layer.masksToBounds = true
        segmentStackView.addArrangedSubview(button)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    private func setSegmentButton(_ button: UIButton, isSelected: Bool) {
        if isSelected {
            button.layer.borderColor = R.color.theme()!.cgColor
            button.setTitleColor(R.color.theme(), for: .normal)
        } else {
            button.layer.borderColor = R.color.line()!.cgColor
            button.setTitleColor(R.color.text(), for: .normal)
        }
    }
    
    private func addContentViewController(_ child: UIViewController) {
        addChild(child)
        contentContainerView.addSubview(child.view)
        child.view.snp.makeEdgesEqualToSuperview()
        child.didMove(toParent: self)
    }
    
}
