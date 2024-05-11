import UIKit
import MixinServices

final class InscriptionViewController: UIViewController {
    
    enum Source {
        case message(messageID: String, snapshotID: String)
        case collectible(inscriptionHash: String)
    }
    
    private enum Row {
        case content
        case action
        case hash
        case id
        case collection
    }
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var tableView: UITableView!
    
    private let source: Source
    private let isMine: Bool // FIXME: Better determination
    
    private lazy var traceID = UUID().uuidString.lowercased()
    
    private var inscription: InscriptionItem?
    private var rows: [Row] = [.content]
    
    init(source: Source, inscription: InscriptionItem?, isMine: Bool) {
        self.source = source
        self.inscription = inscription
        self.isMine = isMine
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
            switch source {
            case .message(let messageID, let snapshotID):
                DispatchQueue.global().async {
                    guard let hash = SafeSnapshotDAO.shared.inscriptionHash(snapshotID: snapshotID) else {
                        return
                    }
                    let job = RefreshInscriptionJob(inscriptionHash: hash, messageID: messageID)
                    NotificationCenter.default.addObserver(self,
                                                           selector: #selector(self.reloadFromNotification(_:)),
                                                           name: RefreshInscriptionJob.didFinishedNotification,
                                                           object: job)
                    ConcurrentJobQueue.shared.addJob(job: job)
                }
            case .collectible(let hash):
                let job = RefreshInscriptionJob(inscriptionHash: hash, messageID: nil)
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(reloadFromNotification(_:)),
                                                       name: RefreshInscriptionJob.didFinishedNotification,
                                                       object: job)
                ConcurrentJobQueue.shared.addJob(job: job)
            }
        }
    }
    
    @IBAction func goBack(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func reloadFromNotification(_ notification: Notification) {
        guard let inscription = notification.userInfo?[RefreshInscriptionJob.dataUserInfoKey] as? InscriptionItem else {
            return
        }
        self.inscription = inscription
        reloadData()
    }
    
    private func reloadData() {
        if inscription == nil {
            rows = [.content]
        } else {
            if isMine {
                // TODO: Add `.action` for inscriptions occupied by myself
                rows = [.content, .hash, .id, .collection]
            } else {
                rows = [.content, .hash, .id, .collection]
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
            if let inscription {
                cell.hashPatternView.content = inscription.inscriptionHash
                cell.hashLabel.text = inscription.inscriptionHash
            }
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
        guard let hash = inscription?.inscriptionHash, let token = TokenDAO.shared.inscriptionToken(inscriptionHash: hash) else {
            return
        }
        let fiatMoneyAmount = token.decimalBalance * token.decimalUSDPrice * Currency.current.decimalRate
        let payment = Payment(traceID: traceID,
                              token: token,
                              tokenAmount: token.decimalBalance,
                              fiatMoneyAmount: fiatMoneyAmount,
                              memo: "")
    }
    
    func inscriptionActionCellRequestToShare(_ cell: InscriptionActionCell) {
        
    }
    
}
