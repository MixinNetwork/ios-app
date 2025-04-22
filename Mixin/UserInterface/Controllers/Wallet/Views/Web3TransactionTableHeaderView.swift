import UIKit

protocol Web3TransactionTableHeaderView: UIView {
    
    var contentStackView: UIStackView! { get }
    var contentStackViewBottomConstraint: NSLayoutConstraint! { get }
    
    var actionView: PillActionView? { get set }
    
}

enum Web3TransactionTableHeaderViewAction: Int, CaseIterable {
    
    case speedUp
    case cancel
    
    var localizedTitle: String {
        switch self {
        case .speedUp:
            R.string.localizable.speed_up()
        case .cancel:
            R.string.localizable.cancel()
        }
    }
    
}

extension Web3TransactionTableHeaderView {
    
    func showActionView() {
        contentStackViewBottomConstraint.constant = 12
        if actionView == nil {
            let actionView = PillActionView()
            actionView.backgroundColor = R.color.background_quaternary()
            actionView.layer.cornerRadius = 12
            actionView.layer.masksToBounds = true
            actionView.actions = Web3TransactionTableHeaderViewAction.allCases
                .map(\.localizedTitle)
            contentStackView.addArrangedSubview(actionView)
            actionView.snp.makeConstraints { make in
                make.height.equalTo(44)
                make.width.equalToSuperview().offset(-32)
            }
            self.actionView = actionView
        }
    }
    
    func hideActionView() {
        contentStackViewBottomConstraint.constant = 16
        actionView?.removeFromSuperview()
    }
    
}
