import UIKit
import Photos

class MyQRCodeWindow: BottomSheetView {

    @IBOutlet weak var qrcodeAvatarImageView: AvatarImageView!
    @IBOutlet weak var qrcodeImageView: UIImageView!
    @IBOutlet weak var qrcodeView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()

        qrcodeAvatarImageView.layer.borderColor = UIColor.white.cgColor
        qrcodeAvatarImageView.layer.borderWidth = 2
        layoutIfNeeded()
        render()
    }

    internal func render() {
        if let account = AccountAPI.shared.account {
            qrcodeImageView.image = UIImage(qrcode: account.code_url, size: qrcodeImageView.frame.size, foregroundColor: UIColor.systemTint)
            qrcodeAvatarImageView.setImage(with: account)
        }
    }

    @IBAction func dismissAction(_ sender: Any) {
        dismissView()
    }

    @IBAction func moreAction(_ sender: Any) {
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.CHAT_PHOTO_SAVE, style: .default, handler: { [weak self](_) in
            self?.saveToLibrary()
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        UIApplication.currentActivity()?.present(alc, animated: true, completion: nil)
    }

    private func saveToLibrary() {
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
                    NotificationCenter.default.postOnMain(name: .ToastMessageDidAppear, object: Localized.CAMERA_SAVE_PHOTO_SUCCESS)
                } else {
                    NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.CAMERA_SAVE_PHOTO_FAILED)
                }
            }
        })
    }

    class func instance() -> MyQRCodeWindow {
        return Bundle.main.loadNibNamed("MyQRCodeWindow", owner: nil, options: nil)?.first as! MyQRCodeWindow
    }
}
