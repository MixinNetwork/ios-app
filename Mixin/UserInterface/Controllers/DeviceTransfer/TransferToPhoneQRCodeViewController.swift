import UIKit
import Combine
import MixinServices

class TransferToPhoneQRCodeViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var tipLabel: UILabel!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
    
    private var stateObserver: AnyCancellable?
    private var server: DeviceTransferServer!
    private var startTransfering = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        LoginManager.shared.inDeviceTransfer = true
        if let server = try? DeviceTransferServer(), let ip = NetworkInterface.firstEthernetHostname() {
            self.server = server
            stateObserver = server.$displayState
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: stateDidChange(_:))
            server.start()
            let pushCommand = DeviceTransferCommand(action: .push, ip: ip, port: Int(server.port), code: server.code)
            guard let jsonData = try? JSONEncoder.default.encode(pushCommand) else {
                return
            }
            let data = jsonData.base64RawURLEncodedString()
            let content = "mixin://device-transfer?data=\(data)"
            let size = CGSize(width: imageViewWidthConstraint.constant, height: imageViewHeightConstraint.constant)
            imageView.image = UIImage(qrcode: content, size: size, foregroundColor: .black)
            updateLabelText()
        } else {
            alert(R.string.localizable.connection_establishment_failed())
            Logger.general.debug(category: "TransferToPhoneQRCodeViewController", message: "Failed to launch server")
        }
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
    
    private func stateDidChange(_ state: DeviceTransferDisplayState) {
        switch state {
        case .connected:
            startTransfering = true
            stateObserver?.cancel()
            let viewController = DeviceTransferProgressViewController(intent: .transferToPhone(server))
            navigationController?.pushViewController(viewController, animated: true)
        case let .failed(error):
            switch error {
            case .mismatchedUserId:
                alert(R.string.localizable.unable_synced_between_different_account(), message: nil)
            case .mismatchedCode:
                alert(R.string.localizable.connection_establishment_failed(), message: nil)
            case .exception, .completed:
                break
            }
        case .preparing, .transporting, .ready, .finished, .closed:
            break
        }
    }
    
    private func updateLabelText() {
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
        LoginManager.shared.inDeviceTransfer = false
        if LoginManager.shared.loggedOutInDeviceTransfer {
            LoginManager.shared.loggedOutInDeviceTransfer = false
            LoginManager.shared.logout(reason: "Device Transfer")
        } else if isBackAction {
            navigationController?.popViewController(animated: true)
        }
    }
    
}
