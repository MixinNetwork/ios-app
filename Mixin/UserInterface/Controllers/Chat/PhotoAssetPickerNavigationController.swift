import UIKit
import Photos

protocol PhotoAssetPickerDelegate: class {
    func pickerController(_ picker: PickerViewController, didFinishPickingMediaWithAsset asset: PHAsset)
}

class PhotoAssetPickerNavigationController: UINavigationController {
    
    weak var pickerDelegate: PhotoAssetPickerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    
    class func instance(pickerDelegate: PhotoAssetPickerDelegate?, isFilterCustomSticker: Bool = false) -> UIViewController {
        let vc = Storyboard.photo.instantiateInitialViewController() as! PhotoAssetPickerNavigationController
        vc.pickerDelegate = pickerDelegate
        let picker = ContainerViewController.instance(viewController: PickerViewController.instance(isFilterCustomSticker: isFilterCustomSticker),
                                                      title: Localized.IMAGE_PICKER_TITLE_CAMERA_ROLL)
        vc.viewControllers = [AlbumViewController.instance(isFilterCustomSticker: isFilterCustomSticker), picker]
        return vc
    }
    
}

extension PhotoAssetPickerNavigationController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
    
}
