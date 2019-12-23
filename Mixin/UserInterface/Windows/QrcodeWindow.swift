import UIKit
import Photos
import MixinServices

class QrcodeWindow: BottomSheetView {
    
    @IBOutlet weak var qrcodeImageView: UIImageView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    @IBOutlet weak var qrcodeView: UIView!
    
    var isShowingMyQrCode = false
    
    func render(conversation: ConversationItem) {
        guard let conversationCodeUrl = conversation.codeUrl else {
            return
        }
        render(title: conversation.name,
               description: Localized.GROUP_QR_CODE_PROMPT,
               qrcode: conversationCodeUrl,
               qrcodeForegroundColor: .black)
        avatarImageView.isHidden = false
        assetIconView.isHidden = true
        avatarImageView.setGroupImage(conversation: conversation)
    }
    
    func render(title: String, description: String, account: Account) {
        render(title: Localized.CONTACT_MY_QR_CODE,
               description: Localized.MYQRCODE_PROMPT,
               qrcode: account.code_url,
               qrcodeForegroundColor: .systemTint)
        avatarImageView.isHidden = false
        assetIconView.isHidden = true
        avatarImageView.setImage(with: account)
        isShowingMyQrCode = true
    }
    
    func renderMoneyReceivingCode(account: Account) {
        render(title: R.string.localizable.contact_receive_money(),
               description: R.string.localizable.transfer_qrcode_prompt(),
               qrcode: "mixin://transfer/\(account.user_id)",
               qrcodeForegroundColor: .black)
        avatarImageView.isHidden = false
        assetIconView.isHidden = true
        avatarImageView.setImage(with: account)
    }
    
    func render(title: String, content: String, asset: AssetItem) {
        render(title: title,
               description: content,
               qrcode: content,
               qrcodeForegroundColor: .black)
        avatarImageView.isHidden = true
        assetIconView.isHidden = false
        assetIconView.setIcon(asset: asset)
    }
    
    private func render(title: String, description: String, qrcode: String, qrcodeForegroundColor: UIColor) {
        titleLabel.text = title
        descriptionLabel.text = description
        qrcodeImageView.image = UIImage(qrcode: qrcode, size: qrcodeImageView.frame.size, foregroundColor: qrcodeForegroundColor)
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
                    showAutoHiddenHud(style: .notification, text: Localized.TOAST_SAVED)
                } else {
                    showAutoHiddenHud(style: .notification, text: Localized.TOAST_OPERATION_FAILED)
                }
            }
        })
    }
    
    class func instance() -> QrcodeWindow {
        return Bundle.main.loadNibNamed("QrcodeWindow", owner: nil, options: nil)?.first as! QrcodeWindow
    }
    
}
