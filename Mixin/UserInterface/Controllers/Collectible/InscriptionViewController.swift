import UIKit
import Photos
import SafariServices
import MixinServices

final class InscriptionViewController: UIViewController {
    
    private enum Row {
        case content(InscriptionContent?)
        case action
        case hash(String)
        case id(UInt64)
        case collection(String)
        case contentType(String)
        case rawOwner(String)
        case owners([UserItem], threshold: Int32?)
        case traits([InscriptionItem.NameValueTrait])
    }
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var tableView: UITableView!
    
    let inscriptionHash: String
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    private let output: Output?
    
    private lazy var traceID = UUID().uuidString.lowercased()
    
    private var rows: [Row] = [.content(nil)]
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
        tableView.register(R.nib.inscriptionTraitsCell)
        tableView.register(R.nib.paymentUserGroupCell)
        tableView.dataSource = self
        tableView.delegate = self
        reloadData()
        let job = RefreshInscriptionJob(inscriptionHash: inscriptionHash)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadFromNotification(_:)),
                                               name: RefreshInscriptionJob.didFinishNotification,
                                               object: job)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    @IBAction func goBack(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func showMoreMenu(_ sender: Any) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        switch inscription?.inscriptionContent {
        case .image:
            if backgroundImageView.image != nil {
                sheet.addAction(UIAlertAction(title: R.string.localizable.set_as_avatar(), style: .default, handler: setAsAvatar(_:)))
                sheet.addAction(UIAlertAction(title: R.string.localizable.save_to_camera_roll(), style: .default, handler: saveToLibrary(_:)))
            }
        case .text, .none:
            break
        }
        if output != nil {
            sheet.addAction(UIAlertAction(title: R.string.localizable.view_on_explorer(), style: .default, handler: viewOnExplorer(_:)))
        }
        sheet.addAction(UIAlertAction(title: R.string.localizable.view_on_marketplace(), style: .default, handler: viewOnMarketplace(_:)))
        if output != nil {
            sheet.addAction(UIAlertAction(title: R.string.localizable.release(), style: .destructive, handler: releaseInscription(_:)))
        }
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
        if let inscription {
            rows = [.content(inscription.inscriptionContent)]
            if output != nil {
                rows.append(.action)
            }
            rows.append(contentsOf: [
                .hash(inscriptionHash),
                .id(inscription.sequence),
                .collection(inscription.collectionName),
                .contentType(inscription.contentType)
            ])
            if let owner = inscription.owner {
                if let address = MIXAddress(string: owner) {
                    switch address {
                    case let .user(userID):
                        appendOwner(raw: owner, userID: userID)
                    case let .multisig(threshold, userIDs):
                        appendOwner(raw: owner, userIDs: userIDs, threshold: threshold)
                    case let .mainnet(_, address):
                        rows.append(.rawOwner(address))
                    }
                } else {
                    rows.append(.rawOwner(owner))
                }
            }
            if let traits = inscription.nameValueTraits, !traits.isEmpty {
                rows.append(.traits(traits))
            }
        } else {
            rows = [.content(nil), .hash(inscriptionHash)]
        }
        tableView.reloadData()
        
        switch inscription?.inscriptionContent {
        case let .image(url):
            backgroundImageView.sd_setImage(with: url)
        case let .text(collectionIconURL, _):
            backgroundImageView.sd_setImage(with: collectionIconURL)
        case nil:
            backgroundImageView.sd_cancelCurrentImageLoad()
            backgroundImageView.image = nil
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
    
    private func saveToLibrary(_ action: UIAlertAction) {
        guard let image = backgroundImageView.image else {
            return
        }
        PHPhotoLibrary.checkAuthorization { (authorized) in
            if authorized {
                PHPhotoLibrary.saveImageToLibrary(image: image)
            }
        }
    }
    
    private func viewOnExplorer(_ action: UIAlertAction) {
        guard
            let hash = output?.transactionHash,
            let url = URL(string: "https://mixin.space/tx/\(hash)")
        else {
            return
        }
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }
    
    private func viewOnMarketplace(_ action: UIAlertAction) {
        guard let url = URL(string: "https://rune.fan/items/\(inscriptionHash)") else {
            return
        }
        guard let container = UIApplication.homeContainerViewController else {
            return
        }
        container.presentWebViewController(context: .init(conversationId: "", initialUrl: url))
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
            case .userCancelled, .loggedOut:
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
    
    private func previewForContextMenu(with configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard 
            let identifier = configuration.identifier as? NSIndexPath,
            let cell = tableView.cellForRow(at: identifier as IndexPath)
        else {
            return nil
        }
        let param = UIPreviewParameters()
        param.backgroundColor = .clear
        return UITargetedPreview(view: cell.contentView, parameters: param)
    }
    
    private func appendOwner(row: Row) {
        let replacing = rows.enumerated().first(where: { (_, row) in
            switch row {
            case .rawOwner, .owners:
                true
            default:
                false
            }
        })
        if let index = replacing?.offset {
            UIView.performWithoutAnimation {
                rows[index] = row
                tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
            }
        } else {
            let index: Int
            switch rows.last {
            case .traits:
                index = rows.count - 1
            case .none:
                return
            default:
                index = rows.count
            }
            UIView.performWithoutAnimation {
                rows.insert(row, at: index)
                tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .none)
            }
        }
    }
    
    private func appendOwner(raw: String, userID: String) {
        DispatchQueue.global().async { [weak self] in
            let user: UserItem
            if let item = UserDAO.shared.getUser(userId: userID) {
                user = item
            } else {
                switch UserAPI.showUser(userId: userID) {
                case .success(let response):
                    user = UserItem.createUser(from: response)
                    UserDAO.shared.updateUsers(users: [response])
                case .failure:
                    return
                }
            }
            DispatchQueue.main.async {
                guard let self, self.inscription?.owner == raw else {
                    return
                }
                self.appendOwner(row: .owners([user], threshold: nil))
            }
        }
    }
    
    private func appendOwner(raw: String, userIDs: [String], threshold: Int32) {
        DispatchQueue.global().async { [weak self] in
            var users: [String: UserItem] = UserDAO.shared
                .getUsers(with: userIDs)
                .reduce(into: [:]) { result, item in
                    result[item.userId] = item
                }
            let missingUserIDs = userIDs.filter { id in
                users[id] == nil
            }
            switch UserAPI.showUsers(userIds: missingUserIDs) {
            case .success(let responses):
                UserDAO.shared.updateUsers(users: responses)
                for response in responses {
                    let item: UserItem = .createUser(from: response)
                    users[item.userId] = item
                }
            case .failure:
                return
            }
            let items = userIDs.compactMap { id in users[id] }
            guard items.count == userIDs.count else {
                return
            }
            DispatchQueue.main.async {
                guard let self, self.inscription?.owner == raw else {
                    return
                }
                self.appendOwner(row: .owners(items, threshold: threshold))
            }
        }
    }
    
}

extension InscriptionViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .hide
    }
    
}

extension InscriptionViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.row]
        switch row {
        case let .content(content):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inscription_content, for: indexPath)!
            if let content {
                cell.placeholderImageView.isHidden = true
                cell.contentImageView.isHidden = false
                switch content {
                case .image(let url):
                    cell.contentImageView.contentMode = .scaleAspectFill
                    cell.contentImageView.sd_setImage(with: url)
                case let .text(collectionIconURL, textContentURL):
                    cell.contentImageView.contentMode = .scaleToFill
                    cell.contentImageView.image = R.image.collectible_text_background()
                    cell.setTextContent(collectionIconURL: collectionIconURL,
                                        textContentURL: textContentURL)
                }
            } else {
                cell.placeholderImageView.isHidden = false
                cell.contentImageView.isHidden = true
            }
            return cell
        case .action:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inscription_action, for: indexPath)!
            cell.delegate = self
            return cell
        case let .hash(hash):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inscription_hash, for: indexPath)!
            cell.hashPatternView.content = hash
            cell.hashLabel.text = hash
            return cell
        case let .id(sequence):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
            cell.setInscriptionInfo(caption: R.string.localizable.id(), content: sequence)
            return cell
        case let .collection(name):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
            cell.setInscriptionInfo(caption: R.string.localizable.collection(), content: name)
            return cell
        case let .contentType(type):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
            cell.setInscriptionInfo(caption: R.string.localizable.content_type(), content: type)
            return cell
        case let .rawOwner(owner):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
            cell.setInscriptionInfo(caption: R.string.localizable.collectible_owner(), content: owner)
            return cell
        case let .owners(users, threshold):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.payment_user_group, for: indexPath)!
            cell.overrideUserInterfaceStyle = .dark
            cell.selectionStyle = .none
            cell.contentView.backgroundColor = .clear
            var caption = R.string.localizable.collectible_owner().uppercased()
            if let threshold, users.count > 1 {
                caption += "(\(threshold)/\(users.count))"
            }
            cell.captionLabel.text = caption
            cell.captionLabel.textColor = UIColor(displayP3RgbValue: 0x999999)
            cell.reloadUsers(with: users, checkmarkCondition: .never)
            cell.delegate = self
            return cell
        case let .traits(traits):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inscription_traits, for: indexPath)!
            cell.traits = traits
            return cell
        }
    }
    
}

extension InscriptionViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if case .content(.image(_)) = rows[indexPath.row],
           let cell = tableView.cellForRow(at: indexPath) as? InscriptionContentCell,
           let image = cell.contentImageView.image
        {
            let previewView = ImagePreviewView(image: image, frame: view.bounds)
            let startImageFrame = cell.contentImageView.convert(cell.contentImageView.bounds, to: previewView)
            previewView.dismissAction = { [weak previewView] in
                guard let view = previewView else {
                    return
                }
                UIView.animate(withDuration: 0.3) {
                    view.backgroundView.effect = nil
                    view.closeButton.alpha = 0
                    view.imageView.frame = startImageFrame
                    view.imageView.layer.cornerRadius = cell.imageWrapperView.layer.cornerRadius
                } completion: { _ in
                    view.removeFromSuperview()
                    cell.imageWrapperView.alpha = 1
                }
            }
            view.addSubview(previewView)
            previewView.imageView.frame = startImageFrame
            previewView.imageView.layer.cornerRadius = cell.imageWrapperView.layer.cornerRadius
            let endHeight = ceil(view.bounds.width * (image.size.height / image.size.width))
            let endFrame = CGRect(x: 0,
                                  y: (previewView.bounds.height - endHeight) / 2,
                                  width: previewView.bounds.width,
                                  height: endHeight)
            cell.imageWrapperView.alpha = 0
            UIView.animate(withDuration: 0.3) {
                previewView.backgroundView.effect = UIBlurEffect(style: .dark)
                previewView.closeButton.alpha = 1
                previewView.imageView.frame = endFrame
                previewView.imageView.layer.cornerRadius = 0
            }
        }
    }
    
    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        let content: String
        switch rows[indexPath.row] {
        case let .hash(hash):
            content = hash
        case let .rawOwner(owner):
            content = owner
        default:
            return nil
        }
        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { _ in
            let action = UIAction(title: R.string.localizable.copy(), image: R.image.web.ic_action_copy()) { _ in
                UIPasteboard.general.string = content
                showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
            }
            return UIMenu(title: "", children: [action])
        }
    }
    
    func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        previewForContextMenu(with: configuration)
    }
    
    func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        previewForContextMenu(with: configuration)
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
        selector.onSelect = { [weak selector] (user) in
            cell.sendButton.isBusy = true
            payment.checkPreconditions(
                transferTo: .user(user),
                reference: nil,
                on: navigationController
            ) { reason in
                cell.sendButton.isBusy = false
                switch reason {
                case .userCancelled, .loggedOut:
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
                    if navigationController.viewControllers.last == selector {
                        navigationController.popViewController(animated: false)
                    }
                }
            }
        }
        navigationController.pushViewController(selector, animated: true)
    }
    
    func inscriptionActionCellRequestToShare(_ cell: InscriptionActionCell) {
        guard
            let inscription,
            let output,
            let token = TokenDAO.shared.tokenItem(kernelAssetID: output.asset)
        else {
            return
        }
        let share = ShareInscriptionViewController(inscription: inscription, token: token)
        present(share, animated: true)
    }
    
}

extension InscriptionViewController: ImageCropViewControllerDelegate {
    
    func imageCropViewController(_ controller: ImageCropViewController, didCropImage croppedImage: UIImage) {
        guard let navigationController else {
            return
        }
        guard let avatarBase64 = croppedImage.imageByScaling(to: .avatar)?.asBase64Avatar() else {
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

extension InscriptionViewController: PaymentUserGroupCellDelegate {
    
    func paymentUserGroupCell(_ cell: PaymentUserGroupCell, didSelectMessengerUser item: UserItem) {
        let profile = UserProfileViewController(user: item)
        present(profile, animated: true, completion: nil)
    }
    
}

extension InscriptionViewController {
    
    private class ImagePreviewView: UIView {
        
        let backgroundView = UIVisualEffectView()
        let closeButton = UIButton(type: .system)
        let imageView: UIImageView
        
        var dismissAction: (() -> Void)?
        
        private let image: UIImage
        
        init(image: UIImage, frame: CGRect) {
            self.image = image
            self.imageView = UIImageView(image: image)
            
            super.init(frame: frame)
            
            backgroundView.effect = nil
            addSubview(backgroundView)
            backgroundView.snp.makeEdgesEqualToSuperview()
            
            closeButton.setImage(R.image.ic_title_close(), for: .normal)
            closeButton.overrideUserInterfaceStyle = .dark
            closeButton.tintColor = R.color.icon_tint()
            closeButton.alpha = 0
            closeButton.addTarget(self, action: #selector(dismiss(_:)), for: .touchUpInside)
            addSubview(closeButton)
            closeButton.snp.makeConstraints { make in
                make.top.equalTo(safeAreaLayoutGuide.snp.top)
                make.leading.equalToSuperview().offset(10)
                make.width.height.equalTo(44)
            }
            
            addSubview(imageView)
            imageView.layer.masksToBounds = true
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismiss(_:)))
            let swipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(dismiss(_:)))
            swipeRecognizer.direction = .down
            imageView.addGestureRecognizer(tapRecognizer)
            imageView.addGestureRecognizer(swipeRecognizer)
            imageView.isUserInteractionEnabled = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            Logger.general.debug(category: "InscriptionPreview", message: "Deinitialized")
        }
        
        @objc private func dismiss(_ sender: Any) {
            dismissAction?()
        }
        
    }
    
}
