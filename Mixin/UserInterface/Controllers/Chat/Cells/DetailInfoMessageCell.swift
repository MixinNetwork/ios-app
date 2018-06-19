import UIKit

protocol DetailInfoMessageCellDelegate: class {
    func detailInfoMessageCellDidSelectFullname(_ cell: DetailInfoMessageCell)
}

class DetailInfoMessageCell: MessageCell {
    
    weak var delegate: DetailInfoMessageCellDelegate?
    
    let fullnameButton = UIButton()
    let timeLabel = UILabel()
    let statusImageView = UIImageView()
    let identityIconImageView = UIImageView(image: #imageLiteral(resourceName: "ic_user_bot"))
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? DetailInfoMessageViewModel {
            backgroundImageView.frame = viewModel.backgroundImageFrame
            backgroundImageView.image = viewModel.backgroundImage
            if viewModel.style.contains(.fullname) {
                fullnameButton.frame = viewModel.fullnameFrame
                fullnameButton.setTitle(viewModel.message.userFullName, for: .normal)
                fullnameButton.setTitleColor(viewModel.fullnameColor, for: .normal)
                fullnameButton.isHidden = false
                identityIconImageView.isHidden = !viewModel.message.userIsBot
            } else {
                fullnameButton.isHidden = true
                identityIconImageView.isHidden = true
            }
            timeLabel.frame = viewModel.timeFrame
            timeLabel.text = viewModel.time
            statusImageView.frame = viewModel.statusFrame
            statusImageView.image = viewModel.statusImage
            statusImageView.tintColor = viewModel.statusTintColor
            if viewModel.message.userIsBot {
                identityIconImageView.frame = viewModel.identityIconFrame
            }
        }
    }
    
    override func prepare() {
        super.prepare()
        fullnameButton.titleLabel?.font = DetailInfoMessageViewModel.fullnameFont
        fullnameButton.contentHorizontalAlignment = .left
        fullnameButton.titleLabel?.lineBreakMode = .byTruncatingTail
        fullnameButton.addTarget(self, action: #selector(fullnameAction(_:)), for: .touchUpInside)
        contentView.addSubview(fullnameButton)
        statusImageView.contentMode = .left
        contentView.addSubview(statusImageView)
        timeLabel.backgroundColor = .clear
        timeLabel.font = DetailInfoMessageViewModel.timeFont
        timeLabel.textAlignment = .right
        contentView.addSubview(timeLabel)
        contentView.addSubview(identityIconImageView)
    }
    
    @objc func fullnameAction(_ sender: Any) {
        delegate?.detailInfoMessageCellDidSelectFullname(self)
    }
 
}
