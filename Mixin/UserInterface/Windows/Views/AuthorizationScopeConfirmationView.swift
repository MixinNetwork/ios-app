import UIKit
import MixinServices

protocol AuthorizationScopeConfirmationViewDelegate: AnyObject {
    
    func authorizationScopeConfirmationView(_ view: AuthorizationScopeConfirmationView, validate pin: String)
    
}

class AuthorizationScopeConfirmationView: UIView, XibDesignable {
    
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var numberPadView: NumberPadView!
    @IBOutlet weak var scopeView: AuthorizationScopeTableView!
    @IBOutlet weak var loadingIndicator: ActivityIndicatorView!
    
    weak var delegate: AuthorizationScopeConfirmationViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadXib()
    }
    
    func render(with scopeHandler: AuthorizationScopeHandler) {
        numberPadView.target = pinField
        scopeView.render(scopeItems: scopeHandler.selectedItems, scopeHandler: scopeHandler)
        scopeView.layoutIfNeeded()
        let height = min(ceil(scopeView.tableView.contentSize.height), scopeView.bounds.height)
        scopeView.tableView.snp.updateConstraints { make in
            make.height.equalTo(height)
        }
    }
    
    @IBAction func pinEditingChangedAction(_ sender: Any) {
        guard pinField.text.count == pinField.numberOfDigits else {
            return
        }
        isUserInteractionEnabled = false
        loadingIndicator.startAnimating()
        pinField.isHidden = true
        pinField.receivesInput = false
        delegate?.authorizationScopeConfirmationView(self, validate: pinField.text)
    }
    
    func resetInput() {
        pinField.clear()
        pinField.isHidden = false
        pinField.receivesInput = true
        isUserInteractionEnabled = true
    }
    
}

