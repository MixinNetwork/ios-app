import UIKit

// UIButton does not participate in Auto Layout sizing correctly
// A quick workaround that only applies to few scenearios
final class MultilineTextButton: UIButton {
    
    override var intrinsicContentSize: CGSize {
        guard let label = titleLabel else {
            return super.intrinsicContentSize
        }
        let maxWidth = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        let size = label.sizeThatFits(
            CGSize(
                width: maxWidth - contentEdgeInsets.left - contentEdgeInsets.right,
                height: .greatestFiniteMagnitude
            )
        )
        return CGSize(
            width: super.intrinsicContentSize.width,
            height: size.height + contentEdgeInsets.top + contentEdgeInsets.bottom
        )
    }
    
}
