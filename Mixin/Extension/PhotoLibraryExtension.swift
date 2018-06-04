import Photos

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

}
