import UIKit
import SDWebImage
import MixinServices

final class AppCardV1MessageCell: DetailInfoMessageCell {
    
    let cardContentView = CardContentView()
    
    weak var appButtonDelegate: AppButtonDelegate?
    
    private var buttonsView: AppButtonGroupView?
    
    private var contentLeadingConstraint: NSLayoutConstraint!
    private var contentTrailingConstraint: NSLayoutConstraint!
    private var buttonsLeadingConstraint: NSLayoutConstraint!
    private var buttonsTrailingConstraint: NSLayoutConstraint!
    private var buttonsHeightConstraint: NSLayoutConstraint!
    
    override func prepare() {
        super.prepare()
        messageContentView.addSubview(cardContentView)
        cardContentView.snp.makeConstraints { make in
            make.top.equalTo(backgroundImageView.snp.top).offset(1)
        }
        contentLeadingConstraint = cardContentView.leadingAnchor
            .constraint(equalTo: backgroundImageView.leadingAnchor)
        contentTrailingConstraint = cardContentView.trailingAnchor
            .constraint(equalTo: backgroundImageView.trailingAnchor)
        NSLayoutConstraint.activate([contentLeadingConstraint, contentTrailingConstraint])
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? AppCardV1MessageViewModel {
            contentLeadingConstraint.constant = viewModel.leadingConstant
            contentTrailingConstraint.constant = viewModel.trailingConstant
            cardContentView.reloadData(with: viewModel.content)
            if !viewModel.content.actions.isEmpty {
                let buttonsView: AppButtonGroupView
                if let view = self.buttonsView {
                    view.isHidden = false
                    buttonsView = view
                } else {
                    buttonsView = AppButtonGroupView()
                    messageContentView.addSubview(buttonsView)
                    buttonsView.snp.makeConstraints { make in
                        make.top.equalTo(backgroundImageView.snp.bottom)
                    }
                    buttonsLeadingConstraint = buttonsView.leadingAnchor.constraint(equalTo: backgroundImageView.leadingAnchor)
                    buttonsTrailingConstraint = buttonsView.trailingAnchor.constraint(equalTo: backgroundImageView.trailingAnchor)
                    buttonsHeightConstraint = buttonsView.heightAnchor.constraint(equalToConstant: 0)
                    NSLayoutConstraint.activate([buttonsLeadingConstraint, buttonsTrailingConstraint, buttonsHeightConstraint])
                    self.buttonsView = buttonsView
                }
                buttonsView.layoutButtons(viewModel: viewModel.buttonsViewModel)
                for (i, content) in viewModel.content.actions.enumerated() {
                    let buttonView = buttonsView.buttonViews[i]
                    let button = buttonView.button
                    buttonView.setTitle(content.label,
                                        colorHexString: content.color,
                                        disclosureIndicator: content.isActionExternal)
                    button.tag = i
                    button.removeTarget(self, action: nil, for: .touchUpInside)
                    button.addTarget(self, action: #selector(performButtonAction(_:)), for: .touchUpInside)
                    
                    // According to disassembly result of UIKitCore from iOS 13.4.1
                    // UITableView's context menu handler cancels any context menu interaction
                    // on UIControl subclasses, therefore we have to handle it here
                    let interaction = UIContextMenuInteraction(delegate: self)
                    button.addInteraction(interaction)
                }
                buttonsLeadingConstraint.constant = viewModel.leadingConstant - viewModel.buttonsLeadingMargin
                buttonsTrailingConstraint.constant = viewModel.trailingConstant + viewModel.buttonsTrailingMargin
                buttonsHeightConstraint.constant = viewModel.buttonsViewModel.buttonGroupFrame.height
            } else {
                buttonsView?.isHidden = true
                buttonsHeightConstraint?.constant = 0
            }
        }
    }
    
    @objc private func performButtonAction(_ sender: UIButton) {
        appButtonDelegate?.appButtonCell(self, didSelectActionAt: sender.tag)
    }
    
}

extension AppCardV1MessageCell: UIContextMenuInteractionDelegate {
    
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        appButtonDelegate?.contextMenuConfigurationForAppButtonGroupMessageCell(self)
    }
    
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        appButtonDelegate?.previewForHighlightingContextMenuOfAppButtonGroupMessageCell(self, with: configuration)
    }
    
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        appButtonDelegate?.previewForDismissingContextMenuOfAppButtonGroupMessageCell(self, with: configuration)
    }
    
}

extension AppCardV1MessageCell {
    
    class CardContentView: UIStackView {
        
        private var coverImageView: SDAnimatedImageView?
        private var titleLabel: UILabel?
        private(set) var descriptionLabel: TextLabel?
        
        init() {
            super.init(frame: .zero)
            axis = .vertical
        }
        
        required init(coder: NSCoder) {
            fatalError("Not supported")
        }
        
        func reloadData(with content: AppCardData.V1Content) {
            let hasCoverImage: Bool
            if let url = content.coverURL {
                let imageView: SDAnimatedImageView
                if let view = coverImageView {
                    view.isHidden = false
                    imageView = view
                } else {
                    imageView = SDAnimatedImageView()
                    imageView.clipsToBounds = true
                    imageView.layer.masksToBounds = true
                    imageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    imageView.layer.cornerRadius = 5
                    imageView.snp.makeConstraints { make in
                        make.width.equalTo(imageView.snp.height)
                            .multipliedBy(AppCardV1MessageViewModel.coverRatio)
                    }
                    imageView.contentMode = .scaleAspectFill
                    insertArrangedSubview(imageView, at: 0)
                    setCustomSpacing(AppCardV1MessageViewModel.coverBottomSpacing, after: imageView)
                    self.coverImageView = imageView
                }
                imageView.sd_setImage(with: url)
                hasCoverImage = true
            } else {
                coverImageView?.isHidden = true
                hasCoverImage = false
            }
            
            let hasTitle: Bool
            if let title = content.title, !title.isEmpty {
                let titleLabel: UILabel
                if let label = self.titleLabel {
                    label.isHidden = false
                    titleLabel = label
                } else {
                    titleLabel = UILabel()
                    titleLabel.numberOfLines = 0
                    titleLabel.font = MessageFontSet.appCardV1Title.scaled
                    let marginStackView = UIStackView(arrangedSubviews: [titleLabel])
                    marginStackView.axis = .horizontal
                    marginStackView.layoutMargins = AppCardV1MessageViewModel.labelLayoutMargins
                    if !hasCoverImage {
                        marginStackView.layoutMargins.top = 8
                    }
                    marginStackView.isLayoutMarginsRelativeArrangement = true
                    if coverImageView == nil {
                        addArrangedSubview(marginStackView)
                    } else {
                        insertArrangedSubview(marginStackView, at: 1)
                    }
                    setCustomSpacing(AppCardV1MessageViewModel.otherSpacing, after: marginStackView)
                    self.titleLabel = titleLabel
                }
                titleLabel.text = title
                hasTitle = true
            } else {
                titleLabel?.isHidden = true
                hasTitle = false
            }
            
            if let description = content.description, !description.isEmpty {
                let descriptionLabel: TextLabel
                if let label = self.descriptionLabel {
                    label.isHidden = false
                    descriptionLabel = label
                } else {
                    descriptionLabel = TextLabel()
                    descriptionLabel.backgroundColor = .clear
                    descriptionLabel.textAlignment = .left
                    descriptionLabel.font = MessageFontSet.cardSubtitle.scaled
                    descriptionLabel.textColor = R.color.text_tertiary()!
                    let marginStackView = UIStackView(arrangedSubviews: [descriptionLabel])
                    marginStackView.axis = .horizontal
                    marginStackView.layoutMargins = AppCardV1MessageViewModel.labelLayoutMargins
                    if !hasCoverImage && !hasTitle {
                        marginStackView.layoutMargins.top = 8
                    }
                    marginStackView.isLayoutMarginsRelativeArrangement = true
                    addArrangedSubview(marginStackView)
                    self.descriptionLabel = descriptionLabel
                }
                descriptionLabel.text = description
            } else {
                descriptionLabel?.isHidden = true
            }
        }
    }
    
}
