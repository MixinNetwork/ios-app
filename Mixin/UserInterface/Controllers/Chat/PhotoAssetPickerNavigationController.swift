import UIKit
import Photos

protocol PhotoAssetPickerDelegate: AnyObject {
    func pickerController(_ picker: PickerViewController, contentOffset: CGPoint, didFinishPickingMediaWithAsset asset: PHAsset)
}

class PhotoAssetPickerNavigationController: UINavigationController {
    
    weak var pickerDelegate: PhotoAssetPickerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background()
        navigationBar.standardAppearance = .general
        navigationBar.scrollEdgeAppearance = .general
        navigationBar.tintColor = R.color.icon_tint()
    }
    
    class func instance(pickerDelegate: PhotoAssetPickerDelegate?, showImageOnly: Bool = false, scrollToOffset: CGPoint = CGPoint.zero) -> UIViewController {
        let vc = PhotoAssetPickerNavigationController()
        vc.pickerDelegate = pickerDelegate
        let albums = AlbumViewController.instance(showImageOnly: showImageOnly)
        let picker = PickerViewController.instance(showImageOnly: showImageOnly, scrollToOffset: scrollToOffset)
        vc.viewControllers = [albums, picker]
        return vc
    }
    
}
