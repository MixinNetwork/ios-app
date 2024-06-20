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
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
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
    
    @IBAction func showMoreMenu(_ sender: Any) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if backgroundImageView.image != nil {
            sheet.addAction(UIAlertAction(title: R.string.localizable.set_as_avatar(), style: .default, handler: setAsAvatar(_:)))
        }
        sheet.addAction(UIAlertAction(title: R.string.localizable.release(), style: .destructive, handler: releaseInscription(_:)))
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel))
        present(sheet, animated: true)
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
    
    private func setAsAvatar(_ action: UIAlertAction) {
        guard let image = backgroundImageView.image else {
            return
        }
        let cropController = ImageCropViewController()
        cropController.load(image: image)
        cropController.delegate = self
        cropController.modalPresentationStyle = .fullScreen
        present(cropController, animated: true)
    }
    
    private func releaseInscription(_ action: UIAlertAction) {
        guard
            let navigationController,
            let output,
            let item = inscription,
            let token = TokenDAO.shared.tokenItem(kernelAssetID: output.asset),
            let account = LoginManager.shared.account,
            let context = Payment.InscriptionContext.release(amount: .half, output: output, item: item)
        else {
            return
        }
        let myself = UserItem.createUser(from: account)
        let payment: Payment = .inscription(traceID: traceID, token: token, memo: "", context: context)
        payment.checkPreconditions(
            transferTo: .user(myself),
            reference: nil,
            on: navigationController
        ) { reason in
            switch reason {
            case .userCancelled:
                break
            case .description(let message):
                showAutoHiddenHud(style: .error, text: message)
            }
        } onSuccess: { operation, issues in
            let preview = TransferPreviewViewController(issues: issues,
                                                        operation: operation,
                                                        amountDisplay: .byToken,
                                                        redirection: nil)
            navigationController.present(preview, animated: true)
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
                cell.setContent("\(inscription.sequence)")
            }
            cell.contentTextView.textColor = .white
            cell.backgroundColor = .clear
            return cell
        case .collection:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
            cell.captionLabel.text = R.string.localizable.collection().uppercased()
            if let inscription {
                cell.setContent("\(inscription.collectionName)")
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
            let token = TokenDAO.shared.tokenItem(kernelAssetID: output.asset),
            let context = Payment.InscriptionContext(operation: .transfer, output: output, item: item)
        else {
            return
        }
        let payment: Payment = .inscription(traceID: traceID, token: token, memo: "", context: context)
        let selector = TransferReceiverViewController()
        let container = ContainerViewController.instance(viewController: selector, title: R.string.localizable.send_to_title())
        selector.onSelect = { (user) in
            cell.sendButton.isBusy = true
            payment.checkPreconditions(
                transferTo: .user(user),
                reference: nil,
                on: navigationController
            ) { reason in
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
        guard
            let inscription,
            let output,
            let token = TokenDAO.shared.tokenItem(kernelAssetID: output.asset)
        else {
            return
        }
        let share = ShareInscriptionViewController()
        share.inscription = inscription
        share.token = token
        present(share, animated: true)
    }
    
}

extension InscriptionViewController: ImageCropViewControllerDelegate {
    
    func imageCropViewController(_ controller: ImageCropViewController, didCropImage croppedImage: UIImage) {
        guard let navigationController, let avatarBase64 = croppedImage.imageByScaling(to: .avatar)?.base64 else {
            alert(R.string.localizable.failed_to_compose_avatar())
            return
        }
        let hud = Hud()
        hud.show(style: .busy, text: "", on: navigationController.view)
        AccountAPI.update(fullName: nil, avatarBase64: avatarBase64, completion: { (result) in
            switch result {
            case let .success(account):
                LoginManager.shared.setAccount(account)
                hud.set(style: .notification, text: R.string.localizable.changed())
            case let .failure(error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
        })
    }
    
}
