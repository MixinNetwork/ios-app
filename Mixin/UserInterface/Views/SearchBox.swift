import UIKit

protocol SearchBox {
    var textField: UITextField! { get }
    var separatorLineView: UIView! { get }
    var height: CGFloat { get }
}
