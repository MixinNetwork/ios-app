import UIKit
import SnapKit

class SystemMessageCell: MessageCell {
    
    let label = UILabel()
    
    var backgroundImageViewBottomConstraint: Constraint!
    
    override func prepare() {
        super.prepare()
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        label.textColor = .black
        label.backgroundColor = .clear
        label.numberOfLines = 0
        label.textAlignment = .center
        messageContentView.addSubview(label)
        label.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(6)
            make.leading.greaterThanOrEqualToSuperview().offset(38)
            make.trailing.lessThanOrEqualToSuperview().offset(-38)
        }
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.snp.makeConstraints { (make) in
            make.leading.trailing.equalTo(label).inset(-SystemMessageViewModel.LabelInsets.horizontal)
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
