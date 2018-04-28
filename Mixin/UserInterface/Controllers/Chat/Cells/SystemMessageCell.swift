import UIKit
import SnapKit

class SystemMessageCell: MessageCell {

    @IBOutlet weak var label: UILabel!
    
    var backgroundImageViewBottomConstraint: Constraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.snp.makeConstraints { (make) in
            make.leading.trailing.equalTo(label).inset(-SystemMessageViewModel.labelHorizontalInset)
            make.top.equalToSuperview()
            backgroundImageViewBottomConstraint = make.bottom.equalToSuperview().constraint
        }
    }

    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        backgroundImageView.image = viewModel.backgroundImage
        backgroundImageViewBottomConstraint.update(offset: -viewModel.bottomSeparatorHeight)
        if let viewModel = viewModel as? SystemMessageViewModel {
            label.text = viewModel.text
        }
    }
    
}
