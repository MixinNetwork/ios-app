import UIKit
import MobileCoreServices
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
            controller.addAction(UIAlertAction(title: R.string.localizable.camera(), style: .default, handler: { [weak self] (_) in
                self?.presentCamera()
            }))
        }
        controller.addAction(UIAlertAction(title: R.string.localizable.choose_photo(), style: .default, handler: { [weak self] (_) in
            self?.presentPhoto()
        }))
        controller.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        return controller
    }()


    private lazy var pickerPhotoLibraryController: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.mediaTypes = [UTType.image.identifier]
        picker.delegate = self
        picker.modalPresentationStyle = .overFullScreen
        return picker
    }()

    private lazy var pickerCameraController: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.mediaTypes = [UTType.image.identifier]
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
            viewController.alert(R.string.localizable.permission_denied_camera_hint())
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
    
}

extension ImagePickerController: UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let completion = { [weak self] (image: UIImage) in
            guard let weakSelf = self else {
                return
            }
            if weakSelf.cropImageAfterPicked {
                picker.dismiss(animated: true, completion: {
                    let cropController = ImageCropViewController()
                    cropController.load(image: image)
                    cropController.delegate = self
                    cropController.modalPresentationStyle = .fullScreen
                    weakSelf.present(viewController: cropController)
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

extension ImagePickerController: ImageCropViewControllerDelegate {
    
    func imageCropViewController(_ controller: ImageCropViewController, didCropImage croppedImage: UIImage) {
        delegate?.imagePickerController(self, didPickImage: croppedImage)
    }
    
}

extension ImagePickerController: UINavigationControllerDelegate {
    
}
