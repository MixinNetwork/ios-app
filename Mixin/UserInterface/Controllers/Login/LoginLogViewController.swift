import UIKit
import MixinServices

final class LoginLogViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var textView: UITextView!
    
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
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func saveLog(_ sender: Any) {
        guard let url = Logger.export(conversationID: nil), FileManager.default.fileSize(url.path) > 0 else {
            return
        }
        let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(share, animated: true)
    }
    
    @objc private func copyLog(_ sender: Any) {
        UIPasteboard.general.string = textView.text
            .components(separatedBy: "\n")
            .suffix(256)
            .joined(separator: "\n")
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}
