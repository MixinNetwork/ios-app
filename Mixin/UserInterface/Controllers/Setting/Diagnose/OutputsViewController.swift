import UIKit
import MixinServices

final class OutputsViewController: UITableViewController {
    
    private let token: TokenItem?
    private let pageCount = 50
    
    private var outputs: [Output] = []
    private var isLoading = false
    private var didLoadEarliestOutput = false
    private var hud: Hud?
    
    init(token: TokenItem?) {
        self.token = token
        super.init(style: .plain)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Outputs"
        navigationItem.rightBarButtonItem = .button(
            title: "Force Sync",
            target: self,
            action: #selector(resync(_:))
        )
        tableView.backgroundColor = .background
        tableView.register(R.nib.outputCell)
        loadMoreOutputsIfNeeded()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.output, for: indexPath)!
        let output = outputs[indexPath.row]
        cell.load(output: output, showAssetID: token == nil)
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
    
    @objc private func tokenOutputsDidSync(_ notification: Notification) {
        if let hud {
            if let error = notification.userInfo?[SyncTokenOutputsJob.errorUserInfoKey] as? Error {
                hud.set(style: .error, text: error.localizedDescription)
            } else {
                hud.set(style: .notification, text: R.string.localizable.done())
            }
            hud.scheduleAutoHidden()
        }
        self.outputs = []
        self.tableView.reloadData()
        self.didLoadEarliestOutput = false
        self.loadMoreOutputsIfNeeded()
    }
    
    private func loadMoreOutputsIfNeeded() {
        guard !isLoading && !didLoadEarliestOutput else {
            return
        }
        isLoading = true
        let earliestOutputID = outputs.last?.id
        DispatchQueue.global().async { [kernelAssetID=token?.kernelAssetID, limit=pageCount] in
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
    
    @objc private func resync(_ sender: Any) {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        self.hud = hud
        DispatchQueue.global().async {
            if let token = self.token {
                OutputDAO.shared.deleteAll(kernelAssetID: token.kernelAssetID) {
                    let job = SyncTokenOutputsJob(assetID: token.assetID, kernelAssetID: token.kernelAssetID)
                    NotificationCenter.default.addObserver(self,
                                                           selector: #selector(self.tokenOutputsDidSync(_:)),
                                                           name: SyncTokenOutputsJob.didFinishNotification,
                                                           object: job)
                    ConcurrentJobQueue.shared.addJob(job: job)
                }
            } else {
                OutputDAO.shared.deleteAll() {
                    DispatchQueue.main.async {
                        let job = SyncOutputsJob()
                        ConcurrentJobQueue.shared.addJob(job: job)
                        hud.set(style: .notification, text: R.string.localizable.done())
                        hud.scheduleAutoHidden()
                        self.navigationController?.popViewController(animated: true)
                    }
                }
            }
        }
    }
    
}
