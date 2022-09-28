import UIKit

protocol TransferActionViewDelegate: AnyObject {
    
    func transferActionView(_ view: TransferActionView, didPerform action: TransferActionView.Action)
    
}

class TransferActionView: UIView, XibDesignable {
    
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var receiveButton: UIButton!
    
    var action: Action?
    
    weak var delegate: TransferActionViewDelegate?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadXib()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }
        
    @IBAction func sendAction(_ sender: Any) {
        action = .send
        delegate?.transferActionView(self, didPerform: .send)
    }
    
    @IBAction func receiveAction(_ sender: Any) {
        action = .receive
        delegate?.transferActionView(self, didPerform: .receive)
    }
    
}

extension TransferActionView {
    
    enum Action {
        case send
        case receive
    }
    
}

