import UIKit
import MobileCoreServices
import PhotosUI

protocol AvatarPickerControllerDelegate: AnyObject {
    func avatarPickerController(_ controller: AvatarPickerController, didPickImage image: UIImage)
}

final class AvatarPickerController: NSObject {
    
    weak var viewController: UIViewController?
    weak var delegate: AvatarPickerControllerDelegate?
    
    init(parent: UIViewController, delegate: AvatarPickerControllerDelegate) {
        self.viewController = parent
        self.delegate = delegate
    }
    
    private lazy var cameraController: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.mediaTypes = [UTType.image.identifier]
        picker.delegate = self
        picker.modalPresentationStyle = .overFullScreen
        return picker
    }()
    
    func presentCamera() {
        VideoCaptureDevice.checkAuthorization { [cameraController, weak viewController] in
            cameraController.sourceType = .camera
            if UIImagePickerController.isCameraDeviceAvailable(.front) {
                cameraController.cameraDevice = .front
            }
            viewController?.present(cameraController, animated: true)
        } onDenied: { [weak viewController] (alert) in
            viewController?.present(alert, animated: true)
        }
    }
    
    func presentPhoto() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        viewController?.present(picker, animated: true)
    }
    
}

extension AvatarPickerController: UIImagePickerControllerDelegate {
    
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
    ) {
        picker.presentingViewController?.dismiss(animated: true) { [weak viewController] in
            guard let image = info[.originalImage] as? UIImage else {
                return
            }
            let cropController = ImageCropViewController()
            cropController.load(image: image)
            cropController.delegate = self
            cropController.modalPresentationStyle = .fullScreen
            viewController?.present(cropController, animated: true)
        }
    }
    
}

extension AvatarPickerController: ImageCropViewControllerDelegate {
    
    func imageCropViewController(_ controller: ImageCropViewController, didCropImage croppedImage: UIImage) {
        delegate?.avatarPickerController(self, didPickImage: croppedImage)
    }
    
}

extension AvatarPickerController: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.presentingViewController?.dismiss(animated: true) { [weak self] in
            guard
                let provider = results.first?.itemProvider,
                provider.canLoadObject(ofClass: UIImage.self)
            else {
                return
            }
            provider.loadObject(ofClass: UIImage.self) { (image, error) in
                DispatchQueue.main.async {
                    guard let image = image as? UIImage, let self else {
                        return
                    }
                    let cropController = ImageCropViewController()
                    cropController.load(image: image)
                    cropController.delegate = self
                    cropController.modalPresentationStyle = .fullScreen
                    self.viewController?.present(cropController, animated: true)
                }
            }
        }
    }
    
}

extension AvatarPickerController: UINavigationControllerDelegate {
    // Required by UIImagePickerController for no reason
}
