import UIKit
import Combine
import MixinServices

class TransferToPhoneQRCodeViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var tipLabel: UILabel!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
    
    private var observers: Set<AnyCancellable> = []
    private var server: DeviceTransferServer?
    private var startTransfering = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        LoginManager.shared.inDeviceTransfer = true
        do {
            let server = try DeviceTransferServer()
            server.$state
                .receive(on: DispatchQueue.main)
                .sink { [unowned self] state in
                    self.server(server, didChangeToState: state)
                }
                .store(in: &observers)
            server.$lastConnectionBlockedReason
                .sink { [unowned self] reason in
                    if let reason {
                        self.server(server, didBlockConnection: reason)
                    }
                }
                .store(in: &observers)
            self.server = server
            server.start()
        } catch {
            Logger.general.info(category: "TransferToPhoneQRCode", message: "Failed to start server: \(error)")
            alert(R.string.localizable.connection_establishment_failed()) { _ in
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startTransfering = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard !startTransfering else {
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
    
    private func server(_ server: DeviceTransferServer, didChangeToState state: DeviceTransferServer.State) {
        switch state {
        case .idle:
            break
        case let .listening(hostname, port, code):
            let push = DeviceTransferCommand(action: .push(hostname: hostname, port: port, code: code, userID: myUserId))
            do {
                let jsonData = try JSONEncoder.default.encode(push)
                let data = jsonData.base64RawURLEncodedString()
                let content = "mixin://device-transfer?data=\(data)"
                let size = CGSize(width: imageViewWidthConstraint.constant,
                                  height: imageViewHeightConstraint.constant)
                imageView.image = UIImage(qrcode: content, size: size, foregroundColor: .black)
                updateTipLabel()
                Logger.general.info(category: "TransferToPhoneQRCode", message: "Push command: \(push)")
            } catch {
                Logger.general.error(category: "TransferToPhoneQRCode", message: "Unable to encode: \(error)")
            }
        case .transfer:
            let progress = DeviceTransferProgressViewController(connection: .server(server, .phone))
            navigationController?.pushViewController(progress, animated: true)
        case let .closed(reason):
            switch reason {
            case .finished:
                break
            case .exception(let error):
                alert(R.string.localizable.connection_establishment_failed(), message: error.localizedDescription) { _ in
                    self.navigationController?.popViewController(animated: true)
                }
            }
        }
    }
    
    private func server(_ server: DeviceTransferServer, didBlockConnection reason: DeviceTransferServer.ConnectionBlockedReason) {
        switch reason {
        case .mismatchedUser:
            alert(R.string.localizable.unable_synced_between_different_account(), message: nil)
        case .mismatchedCode:
            alert(R.string.localizable.connection_establishment_failed(), message: nil)
        }
        server.consumeLastConnectionBlockedReason()
    }
    
    private func updateTipLabel() {
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
        tipLabel.attributedText = bulletListString
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
