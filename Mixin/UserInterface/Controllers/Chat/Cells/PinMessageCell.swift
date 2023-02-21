import UIKit
import SnapKit
import MixinServices

class PinMessageCell: MessageCell {
    
    let contentLabel = UILabel()
    let closingQuoteLabel = UILabel()
    
    var backgroundImageViewBottomConstraint: Constraint!
    
    override func prepare() {
        super.prepare()
        [contentLabel, closingQuoteLabel].forEach { label in
            label.font = MessageFontSet.systemMessage.scaled
            label.textColor = .black
            label.backgroundColor = .clear
            label.numberOfLines = 1
            label.textAlignment = .center
            messageContentView.addSubview(label)
        }
        contentLabel.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(6)
            make.leading.greaterThanOrEqualToSuperview().offset(38)
        }
        closingQuoteLabel.snp.makeConstraints { make in
            make.centerY.equalTo(contentLabel)
            make.left.equalTo(contentLabel.snp.right)
            make.trailing.lessThanOrEqualToSuperview().offset(-38)
        }
        closingQuoteLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.snp.makeConstraints { (make) in
            make.leading.equalTo(contentLabel).inset(-PinMessageViewModel.LabelInsets.horizontal)
            make.trailing.equalTo(closingQuoteLabel).inset(-PinMessageViewModel.LabelInsets.horizontal)
            make.top.equalToSuperview()
            backgroundImageViewBottomConstraint = make.bottom.equalToSuperview().constraint
        }
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        backgroundImageView.image = viewModel.backgroundImage
        backgroundImageViewBottomConstraint.update(offset: -viewModel.bottomSeparatorHeight)
        if let viewModel = viewModel as? PinMessageViewModel {
            contentLabel.text = viewModel.text
            if viewModel.isPinnedText {
                closingQuoteLabel.text = "\""
                contentLabel.text?.removeLast()
            } else {
                closingQuoteLabel.text = ""
            }
        }
    }
    
}
