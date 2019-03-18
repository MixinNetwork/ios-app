import UIKit
import Photos

class QrcodeWindow: BottomSheetView {

    @IBOutlet weak var qrcodeImageView: UIImageView!
    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var leftImageView: CornerImageView!
    @IBOutlet weak var rightImageView: UIImageView!
    @IBOutlet weak var qrcodeView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        iconImageView.layer.borderColor = UIColor.white.cgColor
        iconImageView.layer.borderWidth = 2
    }

    func render(conversation: ConversationItem) {
        guard let conversationCodeUrl = conversation.codeUrl else {
            return
        }
        render(title: conversation.name, description: Localized.GROUP_QR_CODE_PROMPT, qrcode: conversationCodeUrl)
        iconImageView.setGroupImage(conversation: conversation)
    }

    func render(title: String, account: Account, description: String, qrcode: String, qrcodeForegroundColor: UIColor? = nil, leftMarkUrl: String? = nil, rightMark: UIImage? = nil) {
        render(title: title, description: description, qrcode: qrcode, qrcodeForegroundColor: qrcodeForegroundColor, leftMarkUrl: leftMarkUrl, rightMark: rightMark)
        iconImageView.setImage(with: account)
    }

    func render(title: String, iconUrl: String, qrcode: String, leftMarkUrl: String? = nil, rightMark: UIImage? = nil) {
        render(title: title, description: qrcode, qrcode: qrcode, leftMarkUrl: leftMarkUrl, rightMark: rightMark)
        iconImageView.sd_setImage(with: URL(string: iconUrl), placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))
    }

    private func render(title: String, description: String, qrcode: String, qrcodeForegroundColor: UIColor? = nil, leftMarkUrl: String? = nil, rightMark: UIImage? = nil) {
        titleLabel.text = title
        descriptionLabel.text = description
        qrcodeImageView.image = UIImage(qrcode: qrcode, size: qrcodeImageView.frame.size, foregroundColor: qrcodeForegroundColor)

        if let leftUrl = leftMarkUrl {
            leftImageView.sd_setImage(with: URL(string: leftUrl))
            leftImageView.isHidden = false
        } else {
            leftImageView.isHidden = true
        }

        if rightMark != nil {
            rightImageView.image = rightMark
            rightImageView.isHidden = false
        } else {
            rightImageView.isHidden = true
        }
    }

    @IBAction func dismissAction(_ sender: Any) {
        dismissView()
    }

    @IBAction func saveAction(_ sender: Any) {
        PHPhotoLibrary.checkAuthorization { [weak self](authorized) in
            guard let weakSelf = self else {
                return
            }
            if authorized {
                weakSelf.performSavingToLibrary()
            } else {
                weakSelf.dismissPopupControllerAnimated()
            }
        }
    }

    private func performSavingToLibrary() {
        guard let image = qrcodeView.takeScreenshot() else {
            return
        }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { [weak self](success, error) in
            DispatchQueue.main.async {
                self?.dismissPopupControllerAnimated()
                if success {
                    showHud(style: .notification, text: Localized.TOAST_SAVED)
                } else {
                    showHud(style: .notification, text: Localized.TOAST_OPERATION_FAILED)
                }
            }
        })
    }

    class func instance() -> QrcodeWindow {
        return Bundle.main.loadNibNamed("QrcodeWindow", owner: nil, options: nil)?.first as! QrcodeWindow
    }

}
