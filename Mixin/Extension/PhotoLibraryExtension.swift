import Photos

extension PHPhotoLibrary {

    static func checkAuthorization(callback: @escaping (Bool) -> Void) {
        let block = { (authorized: Bool) in
            DispatchQueue.main.async {
                callback(authorized)
                if !authorized {
                    UIApplication.currentActivity()?.alertSettings(R.string.localizable.permission_denied_photo_library())
                }
            }
        }

        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized, .limited:
            block(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { (status) in
                switch status {
                case .authorized, .limited:
                    block(true)
                case .denied, .notDetermined, .restricted:
                    block(false)
                @unknown default:
                    block(false)
                }
            }
        case .denied, .restricted:
            block(false)
        @unknown default:
            block(false)
        }
    }

    static func saveImageToLibrary(image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { (success, error) in
            DispatchQueue.main.async {
                if success {
                    showAutoHiddenHud(style: .notification, text: R.string.localizable.photo_saved())
                } else {
                    showAutoHiddenHud(style: .error, text: R.string.localizable.unable_to_save_photo())
                }
            }
        })
    }
}
