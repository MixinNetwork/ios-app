import UIKit
import MixinServices

final class CirclesViewController: UIViewController {
    
    private weak var tableView: UITableView!
    
    private lazy var tableFooterView: CirclesTableFooterView = {
        let view = R.nib.circlesTableFooterView(withOwner: nil)!
        view.label.text = R.string.localizable.circle_info()
        view.button.snp.makeConstraints { (make) in
            make.top.equalTo(view.contentView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        return view
    }()
    private lazy var editNameController = AlertEditorController(presentingViewController: self)
    
    private var embeddedCircles = CircleDAO.shared.embeddedCircles()
    private var userCircles: [CircleItem] = []
    private var currentCircleIndexPath: IndexPath?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = R.string.localizable.circles()
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addCircle(_:))
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(done(_:))
        )
        
        view.backgroundColor = R.color.background()
        let tableView = UITableView(frame: view.bounds)
        tableView.backgroundColor = R.color.background()
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        self.tableView = tableView
        
        tableView.register(R.nib.circleCell)
        tableView.rowHeight = 70
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        reloadCircles()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadCircles),
            name: CircleDAO.circleDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadCircles),
            name: CircleConversationDAO.circleConversationsDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func addCircle(_ sender: Any) {
        let addCircle = R.string.localizable.add_circle()
        let add = R.string.localizable.add()
        editNameController.present(title: addCircle, actionTitle: add) { (alert) in
            guard let name = alert.textFields?.first?.text else {
                return
            }
            self.addCircle(name: name)
        }
    }
    
    @objc private func done(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func reloadCircles() {
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
                    let indexPath: IndexPath
                    if let circleId = AppGroupUserDefaults.User.circleId, let row = circles.firstIndex(where: { $0.circleId == circleId }) {
                        indexPath = IndexPath(row: row, section: 1)
                    } else {
                        indexPath = IndexPath(row: 0, section: 0)
                    }
                    self.setRow(at: indexPath, isCurrent: true)
                }
            }
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
            cell.titleLabel.text = R.string.localizable.mixin()
            cell.subtitleLabel.text = R.string.localizable.all_conversations()
            cell.unreadCount = circle.unreadCount
            cell.setImagePatternColor(id: nil)
        case .user:
            let circle = userCircles[indexPath.row]
            cell.titleLabel.text = circle.name
            cell.subtitleLabel.text = R.string.localizable.circle_subtitle_count(circle.conversationCount)
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
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        UISwipeActionsConfiguration(actions: [deleteAction(forRowAt: indexPath), editAction(forRowAt: indexPath)])
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true) 
        switchToCircle(at: indexPath, dismissAfterFinished: true)
        presentingViewController?.dismiss(animated: true)
    }
    
}

extension CirclesViewController {
    
    private enum Section: Int, CaseIterable {
        case embedded = 0
        case user
    }
    
    private func tableViewCommitEditAction(action: UIContextualAction, indexPath: IndexPath) {
        let circle = userCircles[indexPath.row]
        let editName = R.string.localizable.edit_circle_name()
        let change = R.string.localizable.change()
        let editConversation = R.string.localizable.edit_conversations()
        let cancel = R.string.localizable.cancel()
        
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
    
    private func tableViewCommitDeleteAction(action: UIContextualAction, indexPath: IndexPath) {
        let circle = userCircles[indexPath.row]
        let delete = R.string.localizable.delete_circle()
        let cancel = R.string.localizable.cancel()
        let sheet = UIAlertController(title: circle.name, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: delete, style: .destructive, handler: { (_) in
            let hud = Hud()
            hud.show(style: .busy, text: "")
            CircleAPI.delete(id: circle.circleId) { (result) in
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        CircleDAO.shared.delete(circleId: circle.circleId)
                        DispatchQueue.main.sync {
                            let indexPath = IndexPath(row: 0, section: Section.embedded.rawValue)
                            self.switchToCircle(at: indexPath, dismissAfterFinished: false)
                            self.reloadCircles()
                            hud.set(style: .notification, text: R.string.localizable.deleted())
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
        hud.show(style: .busy, text: "")
        CircleAPI.create(name: name) { (result) in
            switch result {
            case .success(let circle):
                DispatchQueue.global().async {
                    CircleDAO.shared.save(circle: circle)
                    DispatchQueue.main.sync {
                        hud.set(style: .notification, text: R.string.localizable.added())
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
        hud.show(style: .busy, text: "")
        CircleAPI.update(id: circleId, name: name, completion: { result in
            switch result {
            case .success(let circle):
                if circle.circleId == AppGroupUserDefaults.User.circleId {
                    AppGroupUserDefaults.User.circleName = circle.name
                }
                DispatchQueue.global().async {
                    CircleDAO.shared.save(circle: circle)
                    DispatchQueue.main.async {
                        self.reloadCircles()
                        hud.set(style: .notification, text: R.string.localizable.saved())
                        hud.scheduleAutoHidden()
                    }
                }
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            }
        })
    }
    
    private func switchToCircle(at indexPath: IndexPath, dismissAfterFinished: Bool) {
        let section = Section(rawValue: indexPath.section)!
        switch section {
        case .embedded:
            AppGroupUserDefaults.User.circleId = nil
            AppGroupUserDefaults.User.circleName = nil
        case .user:
            let circle = userCircles[indexPath.row]
            AppGroupUserDefaults.User.circleId = circle.circleId
            AppGroupUserDefaults.User.circleName = circle.name
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
    
    private func deleteAction(forRowAt indexPath: IndexPath) -> UIContextualAction {
        UIContextualAction(style: .destructive, title: R.string.localizable.delete()) { [weak self] (action, _, completionHandler: (Bool) -> Void) in
            self?.tableViewCommitDeleteAction(action: action, indexPath: indexPath)
            completionHandler(true)
        }
    }
    
    private func editAction(forRowAt indexPath: IndexPath) -> UIContextualAction {
        let action = UIContextualAction(style: .normal, title: R.string.localizable.edit()) { [weak self] (action, _, completionHandler: (Bool) -> Void) in
            self?.tableViewCommitEditAction(action: action, indexPath: indexPath)
            completionHandler(true)
        }
        action.backgroundColor = .theme
        return action
    }
    
}
