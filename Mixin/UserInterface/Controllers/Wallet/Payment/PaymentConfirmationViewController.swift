import UIKit
import MixinServices

class PaymentConfirmationViewController: UIViewController {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    
    init() {
        let nib = R.nib.paymentConfirmationView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        contentStackView.spacing = 10
        contentStackView.setCustomSpacing(4, after: amountLabel)
        contentStackView.setCustomSpacing(4, after: valueLabel)
    }
    
    func insertMultisigPatternView(viewDidInsert: (MultisigPatternView) -> Void) {
        let patternView = R.nib.multisigPatternView(withOwner: nil)!
        contentStackView.insertArrangedSubview(patternView, at: 0)
        switch ScreenHeight.current {
        case .short:
            contentStackView.setCustomSpacing(6, after: patternView)
        case .medium:
            contentStackView.setCustomSpacing(8, after: patternView)
        case .long, .extraLong:
            contentStackView.setCustomSpacing(16, after: patternView)
        }
        viewDidInsert(patternView)
    }
    
}
