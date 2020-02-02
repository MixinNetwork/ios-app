import UIKit
import Photos

protocol PhotoAssetPickerDelegate: class {
    func pickerController(_ picker: PickerViewController, contentOffset: CGPoint, didFinishPickingMediaWithAsset asset: PHAsset)
}

class PhotoAssetPickerNavigationController: UINavigationController {
    
    weak var pickerDelegate: PhotoAssetPickerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    
    class func instance(pickerDelegate: PhotoAssetPickerDelegate?, isFilterCustomSticker: Bool = false, scrollToOffset: CGPoint = CGPoint.zero) -> UIViewController {
        let vc = R.storyboard.photo.instantiateInitialViewController()!
        vc.pickerDelegate = pickerDelegate
        let albums = AlbumViewController.instance(isFilterCustomSticker: isFilterCustomSticker)
        let picker = ContainerViewController.instance(viewController: PickerViewController.instance(isFilterCustomSticker: isFilterCustomSticker, scrollToOffset: scrollToOffset), title: "")
        vc.viewControllers = [albums, picker]
        return vc
    }
    
}

extension PhotoAssetPickerNavigationController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
    
}
