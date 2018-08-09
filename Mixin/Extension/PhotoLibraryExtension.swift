import Photos
import SwiftMessages

extension PHPhotoLibrary {

    static func checkAuthorization(callback: @escaping (Bool) -> Void) {
        let block = { (authorized: Bool) in
            DispatchQueue.main.async {
                callback(authorized)
                if !authorized {
                    UIApplication.currentActivity()?.alertSettings(Localized.PERMISSION_DENIED_PHOTO_LIBRARY)
                }
            }
        }

        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            block(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { (status) in
                switch status {
                case .authorized:
                    block(true)
                case .denied, .notDetermined, .restricted:
                    block(false)
                }
            }
        case .denied, .restricted:
            block(false)
        }
    }

    static func saveImageToLibrary(image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { (success, error) in
            DispatchQueue.main.async {
                if success {
                    SwiftMessages.showToast(message: Localized.CAMERA_SAVE_PHOTO_SUCCESS, backgroundColor: .hintGreen)
                } else {
                    SwiftMessages.showToast(message: Localized.CAMERA_SAVE_PHOTO_FAILED, backgroundColor: .hintRed)
                }
            }
        })
    }
}
