import AVFoundation
import UIKit

enum VideoCaptureDevice {
    
    static func checkAuthorization(
        onGranted: @escaping () -> Void,
        onDenied: @escaping (UIAlertController) -> Void
    ) {
        assert(Thread.isMainThread)
        
        lazy var settingsAlert = {
            let alert = UIAlertController(
                title: R.string.localizable.permission_denied_camera(),
                message: R.string.localizable.permission_denied_camera_hint(),
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
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        onGranted()
                    } else {
                        onDenied(settingsAlert)
                    }
                }
            }
        case .authorized:
            onGranted()
        case .restricted, .denied:
            fallthrough
        @unknown default:
            onDenied(settingsAlert)
        }
    }
    
}
