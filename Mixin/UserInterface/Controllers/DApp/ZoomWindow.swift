import UIKit

class ZoomWindow: BottomSheetView {

    @IBOutlet weak var zoomButton: UIButton!

    @IBOutlet weak var webViewWrapperHeightConstraint: LayoutConstraintCompat!

    internal var minimumWebViewHeight: CGFloat = 428
    internal var maximumWebViewHeight: CGFloat {
        if #available(iOS 11.0, *) {
            return self.frame.height - 56 - max(safeAreaInsets.top, 20) - safeAreaInsets.bottom
        } else {
            return self.frame.height - 56 - 20
        }
    }
    internal(set) var windowMaximum = false

    override func awakeFromNib() {
        super.awakeFromNib()

        layoutIfNeeded()
        minimumWebViewHeight = webViewWrapperHeightConstraint.constant
    }

    @IBAction func zoomAction(_ sender: Any) {
        toggleZoomAction()
    }

    func zoomAnimation(targetHeight: CGFloat) {
        self.webViewWrapperHeightConstraint.constant = targetHeight
        self.layoutIfNeeded()
    }

    internal func toggleZoomAction() {
        windowMaximum = !windowMaximum
        zoomButton.setImage(windowMaximum ? #imageLiteral(resourceName: "ic_titlebar_min") : #imageLiteral(resourceName: "ic_titlebar_max"), for: .normal)
        let targetHeight = windowMaximum ? maximumWebViewHeight : minimumWebViewHeight
        UIView.animate(withDuration: 0.25) {
            self.zoomAnimation(targetHeight: targetHeight)
        }
    }
    
}
