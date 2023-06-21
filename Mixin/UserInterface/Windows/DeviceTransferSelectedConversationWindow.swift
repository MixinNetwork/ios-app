import UIKit

class DeviceTransferSelectedConversationWindow: BottomSheetView {
    
    typealias DeleteHandler = (_ conversationID: String) -> Void
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var tableViewHeightConstraint: NSLayoutConstraint!
    
    private let rowHeight: CGFloat = 70.0
    private let maxTableViewHeight: CGFloat = 500.0
    
    private var onDelete: DeleteHandler?
    private var selections = [MessageReceiver]() {
        didSet {
            if selections.count == 1 {
                label.text = R.string.localizable.items_selected_one()
            } else {
                label.text = R.string.localizable.items_selected_count(selections.count)
            }
            let height = CGFloat(selections.count) * rowHeight
            tableViewHeightConstraint.constant = min(height, maxTableViewHeight)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CheckmarkPeerCell.nib, forCellReuseIdentifier: CheckmarkPeerCell.reuseIdentifier)
    }
    
    class func instance() -> DeviceTransferSelectedConversationWindow {
        R.nib.deviceTransferSelectedConversationWindow(owner: self)!
    }
    
    func render(selections: [MessageReceiver], onDelete: @escaping DeleteHandler) {
        self.selections = selections
        self.onDelete = onDelete
        self.tableView.reloadData()
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismissPopupController(animated: true)
    }
    
}

extension DeviceTransferSelectedConversationWindow: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        selections.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CheckmarkPeerCell.reuseIdentifier, for: indexPath) as! CheckmarkPeerCell
        cell.render(receiver: selections[indexPath.row])
        return cell
    }
    
}

extension DeviceTransferSelectedConversationWindow: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onDelete?(selections[indexPath.row].conversationId)
        if selections.count == 1 {
            dismissPopupController(animated: true)
        } else {
            selections.remove(at: indexPath.row)
            tableView.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.isSelected = true
    }
    
}
