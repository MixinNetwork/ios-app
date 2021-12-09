import UIKit

protocol WebMoreMenuControllerDelegate: AnyObject {
    func webMoreMenuViewController(_ controller: WebMoreMenuViewController, didSelect item: WebMoreMenuViewController.MenuItem)
}

class WebMoreMenuViewController: UIViewController {
    
    let titleView = R.nib.popupTitleView(owner: nil)!
    let tableViewController = SettingsTableViewController()
    
    var overrideStatusBarStyle: UIStatusBarStyle?
    
    weak var delegate: WebMoreMenuControllerDelegate?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        overrideStatusBarStyle ?? super.preferredStatusBarStyle
    }
    
    private let menuSections: [[MenuItem]]
    private let backgroundView = UIView()
    private let additionalBottomHeight: CGFloat = 60
    
    private var dataSource: SettingsDataSource?
    
    init(sections: [[MenuItem]]) {
        self.menuSections = sections
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
        transitioningDelegate = PopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleView.layer.cornerRadius = 13
        titleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        titleView.clipsToBounds = true
        titleView.closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        view.addSubview(titleView)
        titleView.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalToSuperview()
        }
        
        tableViewController.tableView.isScrollEnabled = false
        addChild(tableViewController)
        view.addSubview(tableViewController.view)
        tableViewController.view.snp.makeConstraints({ (make) in
            make.top.equalTo(titleView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        })
        tableViewController.didMove(toParent: self)
        
        backgroundView.backgroundColor = .background
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { (make) in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(titleView.snp.bottom).offset(-1)
            make.bottom.equalTo(tableViewController.view.snp.top).offset(1)
        }
        
        let sections = menuSections.map { (items) -> SettingsSection in
            let rows = items.map { (item) -> SettingsRow in
                SettingsRow(icon: item.image, title: item.title, accessory: .disclosure)
            }
            return SettingsSection(rows: rows)
        }
        let dataSource = SettingsDataSource(sections: sections)
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableViewController.tableView
        self.dataSource = dataSource
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePreferredContentSizeHeight()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @objc private func close() {
        dismiss(animated: true, completion: nil)
    }
    
    private func updatePreferredContentSizeHeight() {
        view.layoutIfNeeded()
        preferredContentSize.height = titleView.frame.height
            + tableViewController.tableView.contentSize.height
            + max(20, view.safeAreaInsets.bottom)
            + additionalBottomHeight
    }
    
}

extension WebMoreMenuViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = menuSections[indexPath.section][indexPath.row]
        delegate?.webMoreMenuViewController(self, didSelect: item)
    }
    
}

extension WebMoreMenuViewController {
    
    enum MenuItem {
        
        case share
        case float
        case cancelFloat
        case about
        case copyLink
        case refresh
        case openInBrowser
        case viewAuthorization(String)
        
        var image: UIImage? {
            switch self {
            case .share:
                return R.image.web.ic_action_share()
            case .float:
                return R.image.web.ic_action_float()
            case .cancelFloat:
                return R.image.web.ic_action_cancel_float()
            case .about:
                return R.image.web.ic_action_about()
            case .copyLink:
                return R.image.web.ic_action_copy()
            case .refresh:
                return R.image.web.ic_action_refresh()
            case .openInBrowser:
                return R.image.web.ic_action_open_in_browser()
            case .viewAuthorization:
                return R.image.web.ic_action_view_authorization()
            }
        }
        
        var title: String {
            switch self {
            case .share:
                return R.string.localizable.action_share()
            case .float:
                return R.string.localizable.action_float()
            case .cancelFloat:
                return R.string.localizable.action_cancel_float()
            case .about:
                return R.string.localizable.setting_about()
            case .copyLink:
                return R.string.localizable.group_button_title_copy_link()
            case .refresh:
                return R.string.localizable.action_refresh()
            case .openInBrowser:
                return R.string.localizable.action_open_browser()
            case .viewAuthorization:
                return R.string.localizable.action_view_authorization()
            }
        }
        
    }
    
}
