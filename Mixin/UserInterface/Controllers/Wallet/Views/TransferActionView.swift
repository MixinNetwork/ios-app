import UIKit

protocol TransferActionViewDelegate: AnyObject {
    
    func transferActionView(_ view: TransferActionView, didSelect action: TransferActionView.Action)
    
}

class TransferActionView: UIView, XibDesignable {
    
    @IBOutlet weak var buyButton: BusyButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var receiveButton: UIButton!
    
    weak var delegate: TransferActionViewDelegate?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadXib()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }
    
    @IBAction func buyAction(_ sender: Any) {
        delegate?.transferActionView(self, didSelect: .buy)
    }
    
    @IBAction func sendAction(_ sender: Any) {
        delegate?.transferActionView(self, didSelect: .send)
    }
    
    @IBAction func receiveAction(_ sender: Any) {
        delegate?.transferActionView(self, didSelect: .receive)
    }
    
}

extension TransferActionView {
    
    enum Action {
        case buy
        case send
        case receive
    }
    
}

