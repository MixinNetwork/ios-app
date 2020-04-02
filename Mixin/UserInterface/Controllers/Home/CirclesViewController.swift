import UIKit
import MixinServices

class CirclesViewController: UIViewController {
    
    @IBOutlet weak var toggleCirclesButton: UIButton!
    @IBOutlet weak var tableBackgroundView: UIView!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var showTableViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideTableViewConstraint: NSLayoutConstraint!
    
    private let tableFooterButton = UIButton()
    
    private lazy var deleteAction = UITableViewRowAction(style: .destructive,
                                                         title: Localized.MENU_DELETE,
                                                         handler: tableViewCommitDeleteAction(action:indexPath:))
    private lazy var editAction: UITableViewRowAction = {
        let action = UITableViewRowAction(style: .normal,
                                          title: R.string.localizable.menu_edit(),
                                          handler: tableViewCommitEditAction(action:indexPath:))
        action.backgroundColor = .theme
        return action
    }()
    
    private weak var editNameController: UIAlertController?
    
    private var embeddedCircles = CircleDAO.shared.embeddedCircles()
    private var userCircles = CircleDAO.shared.circles()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tableHeaderView = InfiniteTopView()
        tableHeaderView.frame.size.height = 0
        tableView.tableHeaderView = tableHeaderView
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        tableView.layoutIfNeeded()
        tableFooterButton.frame.size.height = tableView.frame.height - tableView.contentSize.height
        tableFooterButton.backgroundColor = .clear
        tableView.tableFooterView = tableFooterButton
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if let parent = parent as? HomeViewController {
            let action = #selector(HomeViewController.toggleCircles(_:))
            tableFooterButton.addTarget(parent, action: action, for: .touchUpInside)
            toggleCirclesButton.addTarget(parent, action: action, for: .touchUpInside)
        }
    }
    
    func setTableViewVisible(_ visible: Bool, animated: Bool, completion: (() -> Void)?) {
        if visible {
            showTableViewConstraint.priority = .defaultHigh
            hideTableViewConstraint.priority = .defaultLow
        } else {
            showTableViewConstraint.priority = .defaultLow
            hideTableViewConstraint.priority = .defaultHigh
        }
        let work = {
            self.view.layoutIfNeeded()
            self.tableBackgroundView.alpha = visible ? 1 : 0
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
            cell.titleLabel.text = "Mixin"
            cell.subtitleLabel.text = R.string.localizable.circle_conversation_count_all()
            cell.unreadMessageCountLabel.text = "\(circle.unreadCount)"
            cell.circleImageView.image = R.image.ic_circle_all()
        case .user:
            let circle = userCircles[indexPath.row]
            cell.titleLabel.text = circle.name
            cell.subtitleLabel.text = R.string.localizable.circle_conversation_count("\(circle.conversationCount)")
            cell.unreadMessageCountLabel.text = "\(circle.unreadCount)"
            cell.circleImageView.image = R.image.ic_circle_user()
        }
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
    
}

extension CirclesViewController {
    
    private enum Section: Int, CaseIterable {
        case embedded = 0
        case user
    }
    
    private func tableViewCommitEditAction(action: UITableViewRowAction, indexPath: IndexPath) {
        let circle = userCircles[indexPath.row]
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: R.string.localizable.circle_action_edit_name(), style: .default, handler: { (_) in
            self.presentEditNameController(circleId: circle.circleId, currentName: circle.name)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.circle_action_edit_conversations(), style: .default, handler: { (_) in
            let vc = CircleEditorViewController.instance(circleId: circle.circleId)
            self.present(vc, animated: true, completion: nil)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    private func tableViewCommitDeleteAction(action: UITableViewRowAction, indexPath: IndexPath) {
        let circle = userCircles[indexPath.row]
        let sheet = UIAlertController(title: circle.name, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: R.string.localizable.circle_action_delete(), style: .destructive, handler: { (_) in

        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    private func presentEditNameController(circleId: String, currentName: String) {
        let title = R.string.localizable.circle_action_edit_name()
        let changeActionTitle = R.string.localizable.dialog_button_change()
        
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.text = currentName
            textField.addTarget(self, action: #selector(self.alertInputChangedAction(_:)), for: .editingChanged)
        }
        
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        
        let changeAction = UIAlertAction(title: changeActionTitle, style: .default, handler: { [unowned alert] _ in
            guard let name = alert.textFields?.first?.text else {
                return
            }
            self.editCircle(with: circleId, name: name)
        })
        changeAction.isEnabled = false
        alert.addAction(changeAction)
        
        present(alert, animated: true, completion: {
            alert.textFields?.first?.selectAll(nil)
        })
    }
    
    @objc private func alertInputChangedAction(_ sender: UITextField) {
        guard let controller = editNameController, let text = controller.textFields?.first?.text else {
            return
        }
        controller.actions[1].isEnabled = !text.isEmpty
    }
    
    private func editCircle(with circleId: String, name: String) {
        print("edit circle \(circleId), with \(name)")
    }
    
}
