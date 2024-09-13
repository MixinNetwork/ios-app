import UIKit
import SDWebImage
import MixinServices

protocol DetailInfoMessageCellDelegate: AnyObject {
    func detailInfoMessageCellDidSelectFullname(_ cell: DetailInfoMessageCell)
}

class DetailInfoMessageCell: MessageCell {
    
    weak var delegate: DetailInfoMessageCellDelegate?
    
    let fullnameButton = UIButton()
    let encryptedImageView = UIImageView(image: R.image.ic_message_encrypted())
    let pinnedImageView = UIImageView(image: R.image.ic_message_pinned())
    let timeLabel = UILabel()
    let statusImageView = SDAnimatedImageView()
    let forwarderImageView = UIImageView(image: R.image.conversation.ic_forwarder_bot())
    let identityIconImageView = SDAnimatedImageView()
    let highlightAnimationDuration: TimeInterval = 0.2
    
    lazy var expiredIconView: UIImageView = {
        let view = UIImageView(image: R.image.ic_chat_clock_fill())
        messageContentView.addSubview(view)
        expiredIconViewIfLoaded = view
        return view
    }()
    
    private(set) weak var expiredIconViewIfLoaded: UIImageView?
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        timeLabel.font = MessageFontSet.time.scaled
        forwarderImageView.tintColor = viewModel.trailingInfoColor
        encryptedImageView.tintColor = viewModel.trailingInfoColor
        pinnedImageView.tintColor = viewModel.trailingInfoColor
        timeLabel.textColor = viewModel.trailingInfoColor
        if let viewModel = viewModel as? DetailInfoMessageViewModel {
            backgroundImageView.frame = viewModel.backgroundImageFrame
            backgroundImageView.image = viewModel.backgroundImage
            if viewModel.style.contains(.fullname) {
                fullnameButton.frame = viewModel.fullnameFrame
                fullnameButton.setTitle(viewModel.message.userFullName, for: .normal)
                fullnameButton.setTitleColor(viewModel.fullnameColor, for: .normal)
                fullnameButton.isHidden = false
            } else {
                fullnameButton.isHidden = true
            }
            if let image = viewModel.identityIconImage {
                identityIconImageView.frame = viewModel.identityIconFrame
                identityIconImageView.image = image
                identityIconImageView.isHidden = false
            } else {
                identityIconImageView.isHidden = true
            }
            forwarderImageView.frame = viewModel.forwarderFrame
            forwarderImageView.isHidden = !viewModel.style.contains(.forwardedByBot)
            encryptedImageView.frame = viewModel.encryptedIconFrame
            encryptedImageView.isHidden = !viewModel.isEncrypted
            pinnedImageView.frame = viewModel.pinnedIconFrame
            pinnedImageView.isHidden = !viewModel.isPinned
            timeLabel.frame = viewModel.timeFrame
            timeLabel.text = viewModel.time
            updateStatusImageView()
            
            if viewModel.message.isExpiredMessage {
                expiredIconView.frame = viewModel.expiredIconFrame
                expiredIconView.isHidden = false
            } else {
                expiredIconViewIfLoaded?.isHidden = true
            }
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        let needsUpdateAppearance = isSelected != selected
        super.setSelected(selected, animated: animated)
        if needsUpdateAppearance {
            updateAppearance(highlight: selected, animated: animated)
        }
    }
    
    override func prepare() {
        super.prepare()
        fullnameButton.titleLabel?.font = MessageFontSet.fullname.scaled
        fullnameButton.adjustsFontForContentSizeCategory = true
        fullnameButton.contentHorizontalAlignment = .left
        fullnameButton.titleLabel?.lineBreakMode = .byTruncatingTail
        fullnameButton.addTarget(self, action: #selector(fullnameAction(_:)), for: .touchUpInside)
        messageContentView.addSubview(fullnameButton)
        
        statusImageView.contentMode = .left
        messageContentView.addSubview(statusImageView)
        
        forwarderImageView.alpha = 0.7
        messageContentView.addSubview(forwarderImageView)
        
        encryptedImageView.alpha = 0.7
        messageContentView.addSubview(encryptedImageView)
        
        pinnedImageView.alpha = 0.7
        messageContentView.addSubview(pinnedImageView)
        
        timeLabel.backgroundColor = .clear
        timeLabel.font = MessageFontSet.time.scaled
        timeLabel.adjustsFontForContentSizeCategory = true
        timeLabel.textAlignment = .right
        messageContentView.addSubview(timeLabel)
        
        messageContentView.addSubview(identityIconImageView)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateStatusImageView()
        }
    }
    
    @objc func fullnameAction(_ sender: Any) {
        delegate?.detailInfoMessageCellDidSelectFullname(self)
    }
 
    func updateAppearance(highlight: Bool, animated: Bool) {
        guard let viewModel = viewModel, let bubbleImageSet = (type(of: viewModel) as? DetailInfoMessageViewModel.Type)?.bubbleImageSet else {
            return
        }
        let shouldHighlight = highlight && !isMultipleSelecting
        let image = bubbleImageSet.image(forStyle: viewModel.style, highlight: shouldHighlight)
        let transition = {
            self.backgroundImageView.image = image
        }
        if animated {
            UIView.transition(with: backgroundImageView,
                              duration: highlightAnimationDuration,
                              options: [.transitionCrossDissolve, .beginFromCurrentState],
                              animations: transition,
                              completion: nil)
        } else {
            transition()
        }
    }
    
    func updateStatusImageView() {
        guard let viewModel = viewModel as? DetailInfoMessageViewModel else {
            return
        }
        statusImageView.frame = viewModel.statusFrame
        statusImageView.tintColor = viewModel.statusTintColor
        statusImageView.image = viewModel.statusImage?.image(traitCollection: traitCollection)
    }
    
}
