import UIKit
import MobileCoreServices
import RSKImageCropper
import Photos

protocol ImagePickerControllerDelegate: AnyObject {
    func imagePickerController(_ controller: ImagePickerController, didPickImage image: UIImage)
}

class ImagePickerController: NSObject {
    
    weak var viewController: UIViewController!
    weak var delegate: ImagePickerControllerDelegate!
    var initialCameraPosition = UIImagePickerController.CameraDevice.rear
    var cropImageAfterPicked = false
    
    init(initialCameraPosition: UIImagePickerController.CameraDevice, cropImageAfterPicked: Bool, parent: UIViewController, delegate: ImagePickerControllerDelegate) {
        self.initialCameraPosition = initialCameraPosition
        self.cropImageAfterPicked = cropImageAfterPicked
        self.viewController = parent
        self.delegate = delegate
    }
    
    private lazy var selectSourceController: UIAlertController = {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            controller.addAction(UIAlertAction(title: Localized.ACTION_CAMERA, style: .default, handler: { [weak self] (_) in
                self?.presentCamera()
            }))
        }
        controller.addAction(UIAlertAction(title: Localized.ACTION_CHOOSE_PHOTO, style: .default, handler: { [weak self] (_) in
            self?.presentPhoto()
        }))
        controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        return controller
    }()


    private lazy var pickerPhotoLibraryController: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.mediaTypes = [kUTTypeImage as String]
        picker.delegate = self
        picker.modalPresentationStyle = .overFullScreen
        return picker
    }()

    private lazy var pickerCameraController: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.mediaTypes = [kUTTypeImage as String]
        picker.delegate = self
        picker.modalPresentationStyle = .overFullScreen
        return picker
    }()

    func presentCamera() {
        guard let viewController = self.viewController else {
            return
        }
        let authorization = AVCaptureDevice.authorizationStatus(for: .video)
        if authorization == .authorized || authorization == .notDetermined {
            pickerCameraController.sourceType = .camera
            if UIImagePickerController.isCameraDeviceAvailable(.front) && initialCameraPosition == .front {
                pickerCameraController.cameraDevice = .front
            } else {
                pickerCameraController.cameraDevice = .rear
            }
            present(viewController: pickerCameraController)
        } else {
            viewController.alert(Localized.PERMISSION_DENIED_CAMERA)
        }
    }

    func presentPhoto() {
       pickerPhotoLibraryController.sourceType = .photoLibrary
       present(viewController: pickerPhotoLibraryController)
    }

    func present() {
        present(viewController: selectSourceController)
    }
    
    private func present(viewController vcToPresent: UIViewController) {
        viewController?.present(vcToPresent, animated: true, completion: nil)
    }
    
    private func cropController(image: UIImage) -> RSKImageCropViewController {
        let cropController = RSKImageCropViewController(image: image, cropMode: .circle)
        cropController.delegate = self
        return cropController
    }

}

extension ImagePickerController: UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let completion = { [weak self] (image: UIImage) in
            guard let weakSelf = self else {
                return
            }
            if weakSelf.cropImageAfterPicked {
                picker.dismiss(animated: true, completion: {
                    weakSelf.present(viewController: weakSelf.cropController(image: image))
                })
            } else {
                picker.dismiss(animated: true, completion: nil)
                weakSelf.delegate?.imagePickerController(weakSelf, didPickImage: image)
            }
        }
        
        if let image = info[.originalImage] as? UIImage {
            completion(image)
        } else if let asset = info[.phAsset] as? PHAsset {
            PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: nil, resultHandler: { (image, _) in
                if let image = image {
                    completion(image)
                }
            })
        }
    }

}

extension ImagePickerController: RSKImageCropViewControllerDelegate {
    func imageCropViewController(_ controller: RSKImageCropViewController, didCropImage croppedImage: UIImage, usingCropRect cropRect: CGRect, rotationAngle: CGFloat) {
        controller.dismiss(animated: true, completion: nil)
        delegate?.imagePickerController(self, didPickImage: croppedImage)
    }

 
    func imageCropViewControllerDidCancelCrop(_ controller: RSKImageCropViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
}

extension ImagePickerController: UINavigationControllerDelegate {
    
}
