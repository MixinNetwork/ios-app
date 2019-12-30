import UIKit
import SnapKit

class ContinueButtonViewController: KeyboardBasedLayoutViewController {
    
    let continueButton = BusyButton()
    
    var keyboardLayoutGuideHeightConstraint: NSLayoutConstraint!
    
    private let keyboardLayoutGuide = UILayoutGuide()
    private let continueButtonLength: CGFloat = 44
    private let continueButtonMargin: CGFloat = 20
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addLayoutGuide(keyboardLayoutGuide)
        keyboardLayoutGuide.snp.makeConstraints { (make) in
            make.leading.trailing.bottom.equalToSuperview()
        }
        keyboardLayoutGuideHeightConstraint = keyboardLayoutGuide.heightAnchor.constraint(equalToConstant: 0)
        keyboardLayoutGuideHeightConstraint.isActive = true
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
            make.bottom.equalTo(keyboardLayoutGuide.snp.top).offset(-continueButtonMargin)
        }
    }
    
    @objc func continueAction(_ sender: Any) {
        
    }
    
    override func layout(for keyboardFrame: CGRect) {
        let height = view.frame.height - keyboardFrame.origin.y
        if height > keyboardLayoutGuideHeightConstraint.constant {
            keyboardLayoutGuideHeightConstraint.constant = height
        }
        view.layoutIfNeeded()
    }
    
}
