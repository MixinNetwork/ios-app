import UIKit
import SnapKit

class ContinueButtonViewController: KeyboardBasedLayoutViewController {
    
    let continueButton = BusyButton()
    
    var continueButtonBottomConstraint: Constraint!
    
    var continueButtonBottomConstant: CGFloat {
        get {
            return continueButtonBottomConstraint.layoutConstraints.first?.constant ?? 0
        }
        set {
            loadViewIfNeeded()
            continueButtonBottomConstraint.update(offset: newValue)
        }
    }
    
    private let continueButtonLength: CGFloat = 44
    private let continueButtonMargin: CGFloat = 20
    
    override func viewDidLoad() {
        super.viewDidLoad()
        continueButton.isHidden = true
        continueButton.busyIndicator.style = .white
        continueButton.busyIndicator.backgroundColor = .theme
        continueButton.busyIndicator.clipsToBounds = true
        continueButton.busyIndicator.layer.cornerRadius = continueButtonLength / 2
        continueButton.setImage(R.image.ic_action_next(), for: .normal)
        continueButton.backgroundColor = .theme
        continueButton.clipsToBounds = true
        continueButton.layer.cornerRadius = continueButtonLength / 2
        continueButton.addTarget(self, action: #selector(continueAction(_:)), for: .touchUpInside)
        view.addSubview(continueButton)
        continueButton.snp.makeConstraints { (make) in
            make.width.height.equalTo(continueButtonLength)
            make.trailing.equalToSuperview().offset(-continueButtonMargin)
            continueButtonBottomConstraint = make.bottom.equalToSuperview().constraint
        }
    }
    
    @objc func continueAction(_ sender: Any) {
        
    }
    
    override func layout(for keyboardFrame: CGRect) {
        let oldOffset = continueButtonBottomConstant
        let newOffset = keyboardFrame.origin.y
            - view.frame.height
            - continueButtonMargin
        if newOffset < oldOffset {
            continueButtonBottomConstant = newOffset
            view.layoutIfNeeded()
        }
    }
    
}
