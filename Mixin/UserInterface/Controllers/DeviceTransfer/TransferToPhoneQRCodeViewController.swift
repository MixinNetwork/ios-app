import UIKit
import Combine
import MixinServices

class TransferToPhoneQRCodeViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
    
    private var observers: Set<AnyCancellable> = []
    private var server: DeviceTransferServer?
    private var startTransfering = false
    
    private let userID = myUserId
    
    override func viewDidLoad() {
        super.viewDidLoad()
        instructionsLabel.attributedText = makeInstructions()
        LoginManager.shared.inDeviceTransfer = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        restartServer()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard !startTransfering else {
            server?.stopListening()
            return
        }
        checkLogout(isBackAction: false)
    }
    
    class func instance() -> UIViewController {
        let vc = TransferToPhoneQRCodeViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.waiting_for_other_device())
    }
    
}

extension TransferToPhoneQRCodeViewController: ContainerViewControllerDelegate {
    
    func barLeftButtonTappedAction() {
        checkLogout(isBackAction: true)
    }
    
}

extension TransferToPhoneQRCodeViewController {
    
    private func restartServer() {
        startTransfering = false
        observers.forEach { $0.cancel() }
        observers.removeAll()
        let server = DeviceTransferServer()
        server.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.server(server, didChangeToState: state)
            }
            .store(in: &observers)
        server.$lastConnectionRejectedReason
            .sink { [weak self] reason in
                if let self, let reason {
                    self.server(server, didBlockConnection: reason)
                }
            }
            .store(in: &observers)
        self.server = server
        server.startListening() { [weak self] error in
            Logger.general.info(category: "TransferToPhoneQRCode", message: "Failed to start listening: \(error)")
            DispatchQueue.main.async {
                self?.presentRestartServerAlert(message: error.localizedDescription)
            }
        }
    }
    
    private func presentRestartServerAlert(message: String?) {
        let controller = UIAlertController(title: R.string.localizable.connection_establishment_failed(), message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: { (_) in
            Logger.general.info(category: "TransferToPhoneQRCode", message: "Cancelled on failure")
            self.navigationController?.popViewController(animated: true)
        }))
        controller.addAction(UIAlertAction(title: R.string.localizable.retry(), style: .default, handler: { (_) in
            Logger.general.info(category: "TransferToPhoneQRCode", message: "Restart server on failure")
            self.restartServer()
        }))
        present(controller, animated: true, completion: nil)
    }
    
    private func server(_ server: DeviceTransferServer, didChangeToState state: DeviceTransferServer.State) {
        assert(Queue.main.isCurrent)
        switch state {
        case .idle:
            break
        case let .listening(hostname, port):
            let context = DeviceTransferCommand.PushContext(hostname: hostname,
                                                            port: port,
                                                            code: server.code,
                                                            key: server.key,
                                                            userID: userID)
            let push = DeviceTransferCommand(action: .push(context))
            do {
                let jsonData = try JSONEncoder.default.encode(push)
                let data = jsonData.base64RawURLEncodedString()
                let content = "mixin://device-transfer?data=\(data)"
                let size = CGSize(width: imageViewWidthConstraint.constant,
                                  height: imageViewHeightConstraint.constant)
                imageView.image = UIImage(qrcode: content, size: size, foregroundColor: .black)
                Logger.general.info(category: "TransferToPhoneQRCode", message: "Push command: \(push)")
            } catch {
                Logger.general.error(category: "TransferToPhoneQRCode", message: "Unable to encode: \(error)")
            }
        case .transfer:
            startTransfering = true
            observers.forEach { $0.cancel() }
            let progress = DeviceTransferProgressViewController(connection: .server(server, .phone))
            navigationController?.pushViewController(progress, animated: true)
        case let .closed(reason):
            switch reason {
            case .finished:
                break
            case .exception(let error):
                presentRestartServerAlert(message: error.localizedDescription)
            }
        }
    }
    
    private func server(_ server: DeviceTransferServer, didBlockConnection reason: DeviceTransferServer.ConnectionRejectedReason) {
        switch reason {
        case .mismatchedUser:
            alert(R.string.localizable.unable_synced_between_different_account(), message: nil)
        case .mismatchedCode:
            alert(R.string.localizable.connection_establishment_failed(), message: nil)
        }
        server.consumeLastConnectionBlockedReason()
    }
    
    private func makeInstructions() -> NSAttributedString {
        let indentation: CGFloat = 10
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: indentation)]
        paragraphStyle.defaultTabInterval = indentation
        paragraphStyle.lineSpacing = 2
        paragraphStyle.paragraphSpacing = 6
        paragraphStyle.headIndent = indentation
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.scaledFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor.title,
            .paragraphStyle: paragraphStyle
        ]
        let bulletAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.scaledFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor.textAccessory
        ]
        let bullet = "• "
        let strings = [
            R.string.localizable.waiting_for_other_device_login(),
            R.string.localizable.waiting_for_other_device_scan(),
            R.string.localizable.keep_running_foreground()
        ]
        let bulletListString = NSMutableAttributedString()
        for string in strings {
            let formattedString: String
            if string == strings.last {
                formattedString = bullet + string
            } else {
                formattedString = bullet + string + "\n"
            }
            let attributedString = NSMutableAttributedString(string: formattedString, attributes: textAttributes)
            let rangeForBullet = NSString(string: formattedString).range(of: bullet)
            attributedString.addAttributes(bulletAttributes, range: rangeForBullet)
            bulletListString.append(attributedString)
        }
        return bulletListString
    }
    
    private func checkLogout(isBackAction: Bool) {
        Logger.general.info(category: "TransferToPhoneQRCode", message: "Check logout: \(isBackAction)")
        LoginManager.shared.inDeviceTransfer = false
        if LoginManager.shared.loggedOutInDeviceTransfer {
            LoginManager.shared.loggedOutInDeviceTransfer = false
            LoginManager.shared.logout(reason: "Device Transfer")
        } else if isBackAction {
            navigationController?.popViewController(animated: true)
        }
    }
    
}
