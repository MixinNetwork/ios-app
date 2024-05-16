import UIKit
import MixinServices

final class InscriptionViewController: UIViewController {
    
    private enum Row {
        case content
        case action
        case hash
        case id
        case collection
    }
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var tableView: UITableView!
    
    private let inscriptionHash: String
    private let output: Output?
    
    private lazy var traceID = UUID().uuidString.lowercased()
    
    private var rows: [Row] = [.content]
    private var inscription: InscriptionItem?
    
    init(output: InscriptionOutput) {
        self.inscriptionHash = output.inscriptionHash
        self.output = output.output
        self.inscription = output.inscription
        super.init(nibName: nil, bundle: nil)
    }
    
    init(inscription: InscriptionItem) {
        self.inscriptionHash = inscription.inscriptionHash
        self.output = nil
        self.inscription = inscription
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(R.nib.inscriptionContentCell)
        tableView.register(R.nib.inscriptionActionCell)
        tableView.register(R.nib.inscriptionHashCell)
        tableView.register(R.nib.authenticationPreviewCompactInfoCell)
        tableView.dataSource = self
        reloadData()
        if inscription == nil {
            let job = RefreshInscriptionJob(inscriptionHash: inscriptionHash)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(reloadFromNotification(_:)),
                                                   name: RefreshInscriptionJob.didFinishedNotification,
                                                   object: job)
            ConcurrentJobQueue.shared.addJob(job: job)
        }
    }
    
    @IBAction func goBack(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func reloadFromNotification(_ notification: Notification) {
        guard let inscription = notification.userInfo?[RefreshInscriptionJob.UserInfoKey.item] as? InscriptionItem else {
            return
        }
        self.inscription = inscription
        reloadData()
    }
    
    private func reloadData() {
        if inscription == nil {
            rows = [.content, .action, .hash]
        } else {
            if output == nil {
                rows = [.content, .hash, .id, .collection]
            } else {
                rows = [.content, .action, .hash, .id, .collection]
            }
        }
        tableView.reloadData()
        if let url = inscription?.inscriptionImageContentURL {
            backgroundImageView.sd_setImage(with: url)
        }
    }
    
}

extension InscriptionViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.row]
        switch row {
        case .content:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inscription_content, for: indexPath)!
            if let inscription {
                cell.placeholderImageView.isHidden = true
                cell.contentImageView.isHidden = false
                cell.contentImageView.sd_setImage(with: inscription.inscriptionImageContentURL)
            } else {
                cell.placeholderImageView.isHidden = false
                cell.contentImageView.isHidden = true
            }
            return cell
        case .action:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inscription_action, for: indexPath)!
            cell.delegate = self
            return cell
        case .hash:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inscription_hash, for: indexPath)!
            cell.hashPatternView.content = inscriptionHash
            cell.hashLabel.text = inscriptionHash
            return cell
        case .id:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
            cell.captionLabel.text = R.string.localizable.id().uppercased()
            if let inscription {
                cell.setContent("\(inscription.sequence)", labelContent: nil)
            }
            cell.contentTextView.textColor = .white
            cell.backgroundColor = .clear
            return cell
        case .collection:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
            cell.captionLabel.text = R.string.localizable.collection().uppercased()
            if let inscription {
                cell.setContent("\(inscription.collectionName)", labelContent: nil)
            }
            cell.contentTextView.textColor = .white
            cell.backgroundColor = .clear
            return cell
        }
    }
    
}

extension InscriptionViewController: InscriptionActionCellDelegate {
    
    func inscriptionActionCellRequestToSend(_ cell: InscriptionActionCell) {
        guard
            let navigationController,
            let output,
            let item = inscription,
            let payment = Payment(traceID: traceID, output: output, item: item)
        else {
            return
        }
        let selector = TransferReceiverViewController()
        let container = ContainerViewController.instance(viewController: selector, title: R.string.localizable.send_to_title())
        selector.onSelect = { (user) in
            cell.sendButton.isBusy = true
            payment.checkPreconditions(transferTo: .user(user),
                                       reference: nil,
                                       on: navigationController)
            { reason in
                cell.sendButton.isBusy = false
                switch reason {
                case .userCancelled:
                    break
                case .description(let message):
                    showAutoHiddenHud(style: .error, text: message)
                }
            } onSuccess: { operation, issues in
                cell.sendButton.isBusy = false
                let preview = TransferPreviewViewController(issues: issues,
                                                            operation: operation,
                                                            amountDisplay: .byToken,
                                                            tokenAmount: payment.tokenAmount,
                                                            fiatMoneyAmount: payment.fiatMoneyAmount,
                                                            redirection: nil)
                navigationController.present(preview, animated: true) {
                    if navigationController.viewControllers.last == container {
                        navigationController.popViewController(animated: false)
                    }
                }
            }
        }
        navigationController.pushViewController(container, animated: true)
    }
    
    func inscriptionActionCellRequestToShare(_ cell: InscriptionActionCell) {
        let link = "https://mixin.space/inscriptions/\(inscriptionHash)"
        let picker = MessageReceiverViewController.instance(content: .text(link))
        navigationController?.pushViewController(picker, animated: true)
    }
    
}
