import Foundation
import UIKit

protocol XibDesignable {
    func loadXib()
}

extension XibDesignable where Self: UIView {
    
    func loadXib() {
        let nibName = String(describing: type(of: self))
        guard let view = Bundle(for: self.classForCoder).loadNibNamed(nibName, owner: self, options: nil)?.first as? UIView else { return }
        layoutMargins = .zero
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        view.snp.makeConstraints{ $0.edges.equalTo(self) }
    }

}
