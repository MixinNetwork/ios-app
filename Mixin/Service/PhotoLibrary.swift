import UIKit
import Photos

enum PhotoLibrary {
    
    enum ImageSource {
        case image(UIImage)
        case url(URL)
    }
    
    static func saveImage(
        source: ImageSource,
        onPermissionDenied: @escaping (UIAlertController) -> Void
    ) {
        checkAuthorization(onDenied: onPermissionDenied) {
            PHPhotoLibrary.shared().performChanges {
                let request = switch source {
                case .image(let image):
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                case .url(let url):
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                }
                request?.creationDate = Date()
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        showAutoHiddenHud(style: .notification, text: R.string.localizable.photo_saved())
                    } else {
                        showAutoHiddenHud(style: .error, text: R.string.localizable.unable_to_save_photo())
                    }
                }
            }
        }
    }
    
    static func saveVideo(
        url: URL,
        onPermissionDenied: @escaping (UIAlertController) -> Void
    ) {
        checkAuthorization(onDenied: onPermissionDenied) {
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                request?.creationDate = Date()
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        showAutoHiddenHud(style: .notification, text: R.string.localizable.saved())
                    } else {
                        showAutoHiddenHud(style: .error, text: R.string.localizable.unable_to_save_video())
                    }
                }
            }
        }
    }
    
    private static func checkAuthorization(
        onDenied: @escaping (UIAlertController) -> Void,
        onGranted: @escaping () -> Void,
    ) {
        assert(Thread.isMainThread)
        
        lazy var settingsAlert = {
            let alert = UIAlertController(
                title: R.string.localizable.permission_denied_photos(),
                message: R.string.localizable.permission_denied_photos_hint(),
                preferredStyle: .alert
            )
            alert.addAction(
                UIAlertAction(
                    title: R.string.localizable.cancel(),
                    style: .cancel,
                    handler: nil
                )
            )
            alert.addAction(
                UIAlertAction(
                    title: R.string.localizable.settings(),
                    style: .default,
                    handler: { (_) in UIApplication.openAppSettings() }
                )
            )
            return alert
        }()
        
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                switch status {
                case .authorized, .limited:
                    DispatchQueue.main.async(execute: onGranted)
                case .notDetermined, .restricted, .denied:
                    fallthrough
                @unknown default:
                    DispatchQueue.main.async {
                        onDenied(settingsAlert)
                    }
                }
            }
        case .authorized, .limited:
            onGranted()
        case .restricted, .denied:
            fallthrough
        @unknown default:
            onDenied(settingsAlert)
        }
    }
    
}
