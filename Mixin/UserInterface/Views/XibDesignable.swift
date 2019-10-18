import Foundation
import UIKit

protocol XibDesignable {
    var nibName: String { get }
    func loadXib()
}

extension XibDesignable where Self: UIView {
    
    var nibName: String {
        return String(describing: type(of: self))
    }
    
    func loadXib() {
        let bundle = Bundle(for: type(of: self))
        guard let view = bundle.loadNibNamed(nibName, owner: self, options: nil)?.first as? UIView else {
            return
        }
        layoutMargins = .zero
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        view.snp.makeEdgesEqualToSuperview()
    }
    
}
