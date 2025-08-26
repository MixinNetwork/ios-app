import UIKit
import MixinServices

final class LoginLogViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var textView: UITextView!
    
    private var exportedLogURLs: [URL] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleView.titleLabel.text = R.string.localizable.mixin_logs()
        titleView.closeButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        let trayView = R.nib.authenticationPreviewDoubleButtonTrayView(withOwner: nil)!
        UIView.performWithoutAnimation {
            trayView.leftButton.setTitle(R.string.localizable.save(), for: .normal)
            trayView.leftButton.layoutIfNeeded()
            trayView.rightButton.setTitle(R.string.localizable.copy(), for: .normal)
            trayView.rightButton.layoutIfNeeded()
        }
        view.addSubview(trayView)
        trayView.snp.makeConstraints { make in
            make.top.equalTo(textView.snp.bottom)
            make.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }
        trayView.leftButton.addTarget(self, action: #selector(saveLog(_:)), for: .touchUpInside)
        trayView.rightButton.addTarget(self, action: #selector(copyLog(_:)), for: .touchUpInside)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.textContainer.lineFragmentPadding = 0
        do {
            textView.text = try String(contentsOf: Logger.login.fileURL, encoding: .utf8)
        } catch {
            textView.text = error.localizedDescription
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        DispatchQueue.global().async { [exportedLogURLs] in
            for url in exportedLogURLs {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func saveLog(_ sender: Any) {
        do {
            let fileManager: FileManager = .default
            let tempURL = try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let loginLogURL = tempURL.appendingPathComponent("login.txt", conformingTo: .text)
            try fileManager.copyItem(at: Logger.login.fileURL, to: loginLogURL)
            let share = UIActivityViewController(activityItems: [loginLogURL], applicationActivities: nil)
            present(share, animated: true)
            exportedLogURLs.append(loginLogURL)
        } catch {
            alert(R.string.localizable.failed(), message: error.localizedDescription)
        }
    }
    
    @objc private func copyLog(_ sender: Any) {
        UIPasteboard.general.string = textView.text
            .components(separatedBy: "\n")
            .suffix(256)
            .joined(separator: "\n")
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}
