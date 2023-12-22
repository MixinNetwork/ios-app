import UIKit
import MixinServices

final class OutputsViewController: UITableViewController {
    
    private let kernelAssetID: String?
    private let pageCount = 50
    private let allowsForceSync: Bool
    
    private var outputs: [Output] = []
    private var isLoading = false
    private var didLoadEarliestOutput = false
    
    init(kernelAssetID: String?) {
        self.kernelAssetID = kernelAssetID
        self.allowsForceSync = kernelAssetID == nil
        super.init(style: .plain)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .background
        tableView.register(R.nib.outputCell)
        loadMoreOutputsIfNeeded()
        if allowsForceSync {
            container?.rightButton.isEnabled = true
            container?.rightButton.isHidden = false
        } else {
            container?.rightButton.isHidden = true
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.output, for: indexPath)!
        let output = outputs[indexPath.row]
        cell.load(output: output, showAssetID: kernelAssetID == nil)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        outputs.count
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard outputs.count - indexPath.row < 5 else {
            return
        }
        loadMoreOutputsIfNeeded()
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
    
    private func loadMoreOutputsIfNeeded() {
        guard !isLoading && !didLoadEarliestOutput else {
            return
        }
        isLoading = true
        let earliestOutputID = outputs.last?.id
        DispatchQueue.global().async { [kernelAssetID, limit=pageCount] in
            let outputs = OutputDAO.shared.outputs(asset: kernelAssetID, before: earliestOutputID, limit: limit)
            let didLoadEarliestOutput = outputs.count < limit
            DispatchQueue.main.async {
                self.outputs.append(contentsOf: outputs)
                self.tableView.reloadData()
                self.isLoading = false
                self.didLoadEarliestOutput = didLoadEarliestOutput
            }
        }
    }
    
}

extension OutputsViewController: ContainerViewControllerDelegate {
    
    func textBarRightButton() -> String? {
        allowsForceSync ? "Force Sync" : nil
    }
    
    func barRightButtonTappedAction() {
        guard allowsForceSync else {
            return
        }
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async {
            OutputDAO.shared.deleteAll() {
                DispatchQueue.main.async {
                    UTXOService.shared.synchronize()
                    hud.set(style: .notification, text: R.string.localizable.done())
                    hud.scheduleAutoHidden()
                    self.navigationController?.popViewController(animated: true)
                }
            }
        }
    }
    
}
