import Foundation
import UIKit

protocol XibDesignable {
    
    var nibName: String { get }
    var contentEdgeInsets: UIEdgeInsets { get }
    
    @discardableResult func loadXib() -> UIView?
    
}

extension XibDesignable where Self: UIView {
    
    var nibName: String {
        return String(describing: type(of: self))
    }
    
    var contentEdgeInsets: UIEdgeInsets {
        return .zero
    }
    
    @discardableResult
    func loadXib() -> UIView? {
        let bundle = Bundle(for: type(of: self))
        guard let view = bundle.loadNibNamed(nibName, owner: self, options: nil)?.first as? UIView else {
            return nil
        }
        layoutMargins = .zero
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        view.snp.makeConstraints { (make) in
            make.edges.equalToSuperview().inset(contentEdgeInsets)
        }
        return view
    }
    
}
