import UIKit
import Photos

protocol PhotoAssetPickerDelegate: AnyObject {
    func pickerController(_ picker: PickerViewController, contentOffset: CGPoint, didFinishPickingMediaWithAsset asset: PHAsset)
}

final class PhotoAssetPickerNavigationController: GeneralAppearanceNavigationController {
    
    weak var pickerDelegate: PhotoAssetPickerDelegate?
    
    class func instance(pickerDelegate: PhotoAssetPickerDelegate?, showImageOnly: Bool = false, scrollToOffset: CGPoint = CGPoint.zero) -> UIViewController {
        let vc = PhotoAssetPickerNavigationController()
        vc.pickerDelegate = pickerDelegate
        let albums = AlbumViewController.instance(showImageOnly: showImageOnly)
        let picker = PickerViewController.instance(showImageOnly: showImageOnly, scrollToOffset: scrollToOffset)
        vc.viewControllers = [albums, picker]
        return vc
    }
    
}
