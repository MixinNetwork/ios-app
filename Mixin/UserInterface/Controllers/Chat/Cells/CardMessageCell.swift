import UIKit
import SnapKit

class CardMessageCell: DetailInfoMessageCell {
    
    @IBOutlet weak var leftView: UIView!
    @IBOutlet weak var rightView: UIView!

    @IBOutlet weak var contentTopConstraint: NSLayoutConstraint!
    
    var leftViewLeadingConstraint: Constraint!
    var rightViewTrailingConstraint: Constraint!
    
    private let contentTopMargin: CGFloat = 14

    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.sendSubview(toBack: backgroundImageView)
        timeLabel.textColor = .infoGray
        leftView.snp.makeConstraints { (make) in
            leftViewLeadingConstraint = make.leading
                .equalTo(backgroundImageView)
                .constraint
        }
        rightView.snp.makeConstraints { (make) in
            rightViewTrailingConstraint = make.trailing
                .equalTo(backgroundImageView)
                .constraint
        }
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? CardMessageViewModel {
            leftViewLeadingConstraint.update(offset: viewModel.leadingConstant)
            rightViewTrailingConstraint.update(offset: viewModel.trailingConstant)
            contentTopConstraint.constant = contentTopMargin + viewModel.fullnameHeight
        }
    }

}
