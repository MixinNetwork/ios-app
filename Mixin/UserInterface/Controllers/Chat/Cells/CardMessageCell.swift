import UIKit
import SnapKit

class CardMessageCell<LeftView: UIView, RightView: UIView>: DetailInfoMessageCell {
    
    let leftView = LeftView()
    let rightView = RightView()
    
    var leftViewLeadingConstraint: NSLayoutConstraint!
    var leftViewWidthConstraint: NSLayoutConstraint!
    var leftViewBottomConstraint: NSLayoutConstraint!
    var rightViewTrailingConstraint: NSLayoutConstraint!
    
    override func prepare() {
        super.prepare()
        messageContentView.addSubview(leftView)
        messageContentView.addSubview(rightView)
        leftViewLeadingConstraint = leftView.leadingAnchor.constraint(equalTo: backgroundImageView.leadingAnchor)
        leftViewWidthConstraint = leftView.widthAnchor.constraint(equalToConstant: CardMessageViewModel.leftViewSideLength)
        leftViewBottomConstraint = backgroundImageView.bottomAnchor.constraint(equalTo: leftView.bottomAnchor)
        leftView.snp.makeConstraints { (make) in
            make.width.equalTo(leftView.snp.height)
        }
        rightViewTrailingConstraint = backgroundImageView.trailingAnchor.constraint(equalTo: rightView.trailingAnchor)
        rightView.snp.makeConstraints { (make) in
            make.leading.equalTo(leftView.snp.trailing).offset(CardMessageViewModel.spacing)
            make.centerY.equalTo(leftView)
        }
        let constraints: [NSLayoutConstraint] = [
            leftViewLeadingConstraint, leftViewWidthConstraint, leftViewBottomConstraint, rightViewTrailingConstraint
        ]
        NSLayoutConstraint.activate(constraints)
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? CardMessageViewModel {
            leftViewLeadingConstraint.constant = viewModel.leadingConstant
            rightViewTrailingConstraint.constant = viewModel.trailingConstant
            
            let leftViewSideLength = type(of: viewModel).leftViewSideLength
            leftViewWidthConstraint.constant = leftViewSideLength
            let diff = leftViewSideLength - CardMessageViewModel.leftViewSideLength
            leftViewBottomConstraint.constant = 18 - diff / 2
        }
    }
    
}
