import UIKit
import SnapKit

class ContinueButtonViewController: KeyboardBasedLayoutViewController {
    
    let continueButton = BusyButton()
    
    var continueButtonBottomConstraint: NSLayoutConstraint!
    
    private let continueButtonLength: CGFloat = 44
    private let continueButtonMargin: CGFloat = 20
    
    override func viewDidLoad() {
        super.viewDidLoad()
        continueButton.isHidden = true
        continueButton.busyIndicator.tintColor = .white
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
        }
        continueButtonBottomConstraint = continueButton.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        continueButtonBottomConstraint.isActive = true
    }
    
    @objc func continueAction(_ sender: Any) {
        
    }
    
    override func layout(for keyboardFrame: CGRect) {
        let newOffset = keyboardFrame.origin.y
            - view.frame.height
            - continueButtonMargin
        if newOffset < continueButtonBottomConstraint.constant {
            continueButtonBottomConstraint.constant = newOffset
            view.layoutIfNeeded()
        }
    }
    
}
