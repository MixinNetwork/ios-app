import UIKit
import Photos

protocol PhotoAssetPickerDelegate: AnyObject {
    func pickerController(_ picker: PickerViewController, contentOffset: CGPoint, didFinishPickingMediaWithAsset asset: PHAsset)
}

class PhotoAssetPickerNavigationController: UINavigationController {
    
    weak var pickerDelegate: PhotoAssetPickerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    
    class func instance(pickerDelegate: PhotoAssetPickerDelegate?, showImageOnly: Bool = false, scrollToOffset: CGPoint = CGPoint.zero) -> UIViewController {
        let vc = R.storyboard.photo.instantiateInitialViewController()!
        vc.pickerDelegate = pickerDelegate
        let albums = AlbumViewController.instance(showImageOnly: showImageOnly)
        let picker = PickerViewController.instance(showImageOnly: showImageOnly, scrollToOffset: scrollToOffset)
        let pickerContainer = ContainerViewController.instance(viewController: picker, title: "")
        vc.viewControllers = [albums, pickerContainer]
        return vc
    }
    
}

extension PhotoAssetPickerNavigationController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
    
}
