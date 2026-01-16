import UIKit
import MixinServices

final class Web3OutputsViewController: UITableViewController {
    
    private let token: Web3Token?
    private let pageCount = 50
    
    private var outputs: [Web3Output] = []
    private var hud: Hud?
    
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
        tableView.backgroundColor = .background
        tableView.register(R.nib.outputCell)
        DispatchQueue.global().async { [token] in
            let outputs = Web3OutputDAO.shared.outputs(token: token)
            DispatchQueue.main.async {
                self.outputs = outputs
                self.tableView.reloadData()
            }
        }
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
    
}
