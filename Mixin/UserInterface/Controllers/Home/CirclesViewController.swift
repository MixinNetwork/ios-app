import UIKit
import MixinServices

class CirclesViewController: UIViewController {
    
    @IBOutlet weak var navigationBarView: UIView!
    @IBOutlet weak var toggleCirclesButton: UIButton!
    @IBOutlet weak var tableBackgroundButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var showTableViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideTableViewConstraint: NSLayoutConstraint!
    
    private lazy var tableFooterView: CirclesTableFooterView = {
        let view = R.nib.circlesTableFooterView(owner: nil)!
        view.label.text = R.string.localizable.circle_add_hint()
        view.button.snp.makeConstraints { (make) in
            make.top.equalTo(view.contentView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        return view
    }()
    private lazy var deleteAction = {
        UITableViewRowAction(style: .destructive,
                             title: Localized.MENU_DELETE,
                             handler: tableViewCommitDeleteAction(action:indexPath:))
    }()
    private lazy var editAction: UITableViewRowAction = {
        let action = UITableViewRowAction(style: .normal,
                                          title: R.string.localizable.menu_edit(),
                                          handler: tableViewCommitEditAction(action:indexPath:))
        action.backgroundColor = .theme
        return action
    }()
    private lazy var editNameController = AlertEditorController(presentingViewController: self)
    
    private var embeddedCircles = CircleDAO.shared.embeddedCircles()
    private var userCircles: [CircleItem] = []
    private var currentCircleIndexPath: IndexPath?
    private var needRefresh = true
    private var refreshing = false
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let title = AppGroupUserDefaults.User.circleName ?? R.string.localizable.app_name()
        toggleCirclesButton.setTitle(title, for: .normal)
        let tableHeaderView = InfiniteTopView()
        tableHeaderView.frame.size.height = 0
        tableView.tableHeaderView = tableHeaderView
        tableView.register(R.nib.circleCell)
        tableView.dataSource = self
        tableView.delegate = self
        reloadCircles()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadUserCircle), name: CircleDAO.circleDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadUserCircle), name: CircleConversationDAO.circleConversationsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadUserCircle), name: MixinServices.conversationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadUserCircle), name: MessageDAO.didInsertMessageNotification, object: nil)
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if let parent = parent as? HomeViewController {
            let action = #selector(HomeViewController.toggleCircles(_:))
            for button in [tableFooterView.button, toggleCirclesButton, tableBackgroundButton] {
                button!.addTarget(parent, action: action, for: .touchUpInside)
            }
        }
    }
    
    @IBAction func newCircleAction(_ sender: Any) {
        let addCircle = R.string.localizable.circle_action_add()
        let add = R.string.localizable.action_add()
        editNameController.present(title: addCircle, actionTitle: add) { (alert) in
            guard let name = alert.textFields?.first?.text else {
                return
            }
            self.addCircle(name: name)
        }
    }
    
    @objc func reloadUserCircle() {
        guard tableBackgroundButton != nil else {
            return
        }
        if tableBackgroundButton.alpha == 1 {
            reloadCircles()
        } else {
            needRefresh = true
        }
    }
    
    func setTableViewVisible(_ visible: Bool, animated: Bool, completion: (() -> Void)?) {
        if visible {
            showTableViewConstraint.priority = .defaultHigh
            hideTableViewConstraint.priority = .defaultLow
            if needRefresh {
                reloadCircles()
            }
        } else {
            showTableViewConstraint.priority = .defaultLow
            hideTableViewConstraint.priority = .defaultHigh
        }
        let work = {
            self.view.layoutIfNeeded()
            self.tableBackgroundButton.alpha = visible ? 1 : 0
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: work) { (_) in
                completion?()
            }
        } else {
            work()
            completion?()
        }
    }
    
}

extension CirclesViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = Section(rawValue: section)!
        switch section {
        case .embedded:
            return embeddedCircles.count
        case .user:
            return userCircles.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.circle, for: indexPath)!
        let section = Section(rawValue: indexPath.section)!
        switch section {
        case .embedded:
            let circle = embeddedCircles[indexPath.row]
            cell.titleLabel.text = R.string.localizable.app_name()
            cell.subtitleLabel.text = R.string.localizable.circle_conversation_count_all()
            cell.unreadCount = circle.unreadCount
            cell.setImagePatternColor(id: nil)
        case .user:
            let circle = userCircles[indexPath.row]
            cell.titleLabel.text = circle.name
            cell.subtitleLabel.text = R.string.localizable.circle_conversation_count("\(circle.conversationCount)")
            cell.unreadCount = circle.unreadCount
            cell.setImagePatternColor(id: circle.circleId)
        }
        cell.isCurrent = indexPath == currentCircleIndexPath
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
}

extension CirclesViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == Section.user.rawValue
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        [deleteAction, editAction]
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true) 
        switchToCircle(at: indexPath, dismissAfterFinished: true)
    }
    
}

extension CirclesViewController {
    
    private enum Section: Int, CaseIterable {
        case embedded = 0
        case user
    }
    
    private func tableViewCommitEditAction(action: UITableViewRowAction, indexPath: IndexPath) {
        let circle = userCircles[indexPath.row]
        let editName = R.string.localizable.circle_action_edit_name()
        let change = R.string.localizable.dialog_button_change()
        let editConversation = R.string.localizable.circle_action_edit_conversations()
        let cancel = R.string.localizable.dialog_button_cancel()
        
        let sheet = UIAlertController(title: circle.name, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: editName, style: .default, handler: { (_) in
            self.editNameController.present(title: editName, actionTitle: change, currentText: circle.name) { (alert) in
                guard let name = alert.textFields?.first?.text else {
                    return
                }
                self.editCircle(with: circle.circleId, name: name)
            }
        }))
        sheet.addAction(UIAlertAction(title: editConversation, style: .default, handler: { (_) in
            let vc = CircleEditorViewController.instance(name: circle.name,
                                                         circleId: circle.circleId,
                                                         isNewCreatedCircle: false)
            self.present(vc, animated: true, completion: nil)
        }))
        sheet.addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
        
        present(sheet, animated: true, completion: nil)
    }
    
    private func tableViewCommitDeleteAction(action: UITableViewRowAction, indexPath: IndexPath) {
        let circle = userCircles[indexPath.row]
        let delete = R.string.localizable.circle_action_delete()
        let cancel = R.string.localizable.dialog_button_cancel()
        let sheet = UIAlertController(title: circle.name, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: delete, style: .destructive, handler: { (_) in
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            CircleAPI.delete(id: circle.circleId) { (result) in
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        CircleDAO.shared.delete(circleId: circle.circleId)
                        DispatchQueue.main.sync {
                            let indexPath = IndexPath(row: 0, section: Section.embedded.rawValue)
                            self.switchToCircle(at: indexPath, dismissAfterFinished: false)
                            self.reloadCircles()
                            hud.set(style: .notification, text: R.string.localizable.toast_deleted())
                            hud.scheduleAutoHidden()
                        }
                    }
                case .failure(let error):
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                }
            }
        }))
        sheet.addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    private func addCircle(name: String) {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        CircleAPI.create(name: name) { (result) in
            switch result {
            case .success(let circle):
                DispatchQueue.global().async {
                    CircleDAO.shared.save(circle: circle)
                    DispatchQueue.main.sync {
                        hud.set(style: .notification, text: R.string.localizable.toast_added())
                        hud.scheduleAutoHidden()
                        let vc = CircleEditorViewController.instance(name: circle.name,
                                                                     circleId: circle.circleId,
                                                                     isNewCreatedCircle: true)
                        self.present(vc, animated: true, completion: nil)
                    }
                }
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            }
        }
    }
    
    private func editCircle(with circleId: String, name: String) {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        CircleAPI.update(id: circleId, name: name, completion: { result in
            switch result {
            case .success(let circle):
                if circle.circleId == AppGroupUserDefaults.User.circleId {
                    AppGroupUserDefaults.User.circleName = circle.name
                    self.toggleCirclesButton.setTitle(circle.name, for: .normal)
                }
                DispatchQueue.global().async {
                    CircleDAO.shared.save(circle: circle)
                    DispatchQueue.main.async {
                        self.reloadCircles()
                        hud.set(style: .notification, text: R.string.localizable.toast_saved())
                        hud.scheduleAutoHidden()
                    }
                }
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            }
        })
    }

    private func reloadCircles() {
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        guard !refreshing else {
            needRefresh = true
            return
        }
        refreshing = true
        needRefresh = false

        DispatchQueue.global().async { [weak self] in
            let embeddedCircles = CircleDAO.shared.embeddedCircles()
            let circles = CircleDAO.shared.circles()
            DispatchQueue.main.async {
                if let self = self {
                    self.embeddedCircles = embeddedCircles
                    self.userCircles = circles
                    self.tableView.reloadData()
                    self.tableFooterView.showsHintLabel = circles.isEmpty
                    self.tableView.tableFooterView = self.tableFooterView
                    self.tableView.layoutIfNeeded()
                    let cellsHeight = CGFloat(circles.count + 1) * self.tableView.rowHeight
                    let height = max(self.tableFooterView.contentView.frame.height,
                                     self.tableView.frame.height - self.tableView.adjustedContentInset.vertical - cellsHeight)
                    self.tableFooterView.frame.size.height = height
                    self.tableView.tableFooterView = self.tableFooterView
                    let indexPath: IndexPath
                    if let circleId = AppGroupUserDefaults.User.circleId, let row = circles.firstIndex(where: { $0.circleId == circleId }) {
                        indexPath = IndexPath(row: row, section: 1)
                    } else {
                        indexPath = IndexPath(row: 0, section: 0)
                    }
                    self.setRow(at: indexPath, isCurrent: true)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.33, execute: {
                    self?.refreshing = false
                    if self?.needRefresh ?? false {
                        self?.reloadCircles()
                    }
                })
            }
        }
    }
    
    private func switchToCircle(at indexPath: IndexPath, dismissAfterFinished: Bool) {
        let section = Section(rawValue: indexPath.section)!
        let circleName: String
        switch section {
        case .embedded:
            AppGroupUserDefaults.User.circleId = nil
            AppGroupUserDefaults.User.circleName = nil
            circleName = R.string.localizable.app_name()
        case .user:
            let circle = userCircles[indexPath.row]
            AppGroupUserDefaults.User.circleId = circle.circleId
            AppGroupUserDefaults.User.circleName = circle.name
            circleName = circle.name
        }
        UIView.performWithoutAnimation {
            toggleCirclesButton.setTitle(circleName, for: .normal)
            navigationBarView.setNeedsLayout()
            navigationBarView.layoutIfNeeded()
        }
        if let home = parent as? HomeViewController {
            home.setNeedsRefresh()
            if dismissAfterFinished {
                home.toggleCircles(self)
            }
        }
        setRow(at: indexPath, isCurrent: true)
    }
    
    private func setRow(at indexPath: IndexPath, isCurrent: Bool) {
        if let indexPath = currentCircleIndexPath, let cell = tableView.cellForRow(at: indexPath) as? CircleCell {
            cell.isCurrent = false
        }
        if let cell = tableView.cellForRow(at: indexPath) as? CircleCell {
            cell.isCurrent = true
        }
        currentCircleIndexPath = indexPath
    }
    
}
