import UIKit
import MixinServices

final class Web3OutputsViewController: UITableViewController {
    
    private let token: Web3Token?
    private let pageCount = 50
    
    private var outputs: [Web3Output] = []
    
    init(token: Web3Token?) {
        self.token = token
        super.init(style: .plain)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Web3 Outputs"
        navigationItem.rightBarButtonItems = [
            .tintedIcon(
                image: UIImage(systemName: "trash"),
                target: self,
                action: #selector(deleteAll(_:))
            ),
            .tintedIcon(
                image: UIImage(systemName: "tray.and.arrow.up"),
                target: self,
                action: #selector(copyAsJSON(_:))
            ),
        ]
        tableView.backgroundColor = .background
        tableView.register(R.nib.outputCell)
        reloadData()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.output, for: indexPath)!
        let output = outputs[indexPath.row]
        cell.load(output: output, showAddress: token == nil)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        outputs.count
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let output = outputs[indexPath.row]
        let copyAction = UIContextualAction(style: .normal, title: R.string.localizable.copy(), handler: { _, _, completion in
            let json: String?
            if let data = try? JSONEncoder.default.encode(output) {
                json = String(data: data, encoding: .utf8)
            } else {
                json = nil
            }
            if let json {
                UIPasteboard.general.string = json
                showAutoHiddenHud(style: .notification, text: R.string.localizable.done())
            } else {
                showAutoHiddenHud(style: .error, text: "Unable to encode")
            }
            completion(true)
        })
        copyAction.backgroundColor = .theme
        return UISwipeActionsConfiguration(actions: [copyAction])
    }
    
    private func reloadData() {
        DispatchQueue.global().async { [token] in
            let outputs = Web3OutputDAO.shared.outputs(token: token)
            DispatchQueue.main.async {
                self.outputs = outputs
                self.tableView.reloadData()
            }
        }
    }
    
    @objc private func copyAsJSON(_ sender: Any) {
        let json: String?
        if let data = try? JSONEncoder.default.encode(outputs) {
            json = String(data: data, encoding: .utf8)
        } else {
            json = nil
        }
        if let json {
            UIPasteboard.general.string = json
            showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
        } else {
            showAutoHiddenHud(style: .error, text: "Failed")
        }
    }
    
    @objc private func deleteAll(_ sender: Any) {
        Web3OutputDAO.shared.deleteAll()
        reloadData()
    }
    
}
