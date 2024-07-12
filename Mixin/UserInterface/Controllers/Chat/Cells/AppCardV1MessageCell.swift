import UIKit

final class AppCardV1MessageCell: DetailInfoMessageCell {
    
    weak var appButtonDelegate: AppButtonDelegate?
    
    private let stackView = UIStackView()
    
    private var coverImageView: UIImageView?
    private var titleLabel: UILabel?
    private(set) var descriptionLabel: TextLabel?
    private var buttonsView: AppButtonGroupView?
    
    private var contentLeadingConstraint: NSLayoutConstraint!
    private var contentTrailingConstraint: NSLayoutConstraint!
    private var buttonsLeadingConstraint: NSLayoutConstraint!
    private var buttonsTrailingConstraint: NSLayoutConstraint!
    private var buttonsHeightConstraint: NSLayoutConstraint!
    
    override func prepare() {
        super.prepare()
        stackView.axis = .vertical
        messageContentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalTo(backgroundImageView.snp.top).offset(1)
        }
        contentLeadingConstraint = stackView.leadingAnchor.constraint(equalTo: backgroundImageView.leadingAnchor)
        contentTrailingConstraint = stackView.trailingAnchor.constraint(equalTo: backgroundImageView.trailingAnchor)
        NSLayoutConstraint.activate([contentLeadingConstraint, contentTrailingConstraint])
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? AppCardV1MessageViewModel {
            contentLeadingConstraint.constant = viewModel.leadingConstant
            contentTrailingConstraint.constant = viewModel.trailingConstant
            
            if let url = viewModel.content.coverURL {
                let imageView: UIImageView
                if let view = coverImageView {
                    view.isHidden = false
                    imageView = view
                } else {
                    imageView = UIImageView()
                    imageView.clipsToBounds = true
                    imageView.layer.masksToBounds = true
                    imageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    imageView.layer.cornerRadius = 5
                    imageView.snp.makeConstraints { make in
                        make.width.equalTo(imageView.snp.height)
                            .multipliedBy(viewModel.coverRatio)
                    }
                    imageView.contentMode = .scaleAspectFill
                    stackView.insertArrangedSubview(imageView, at: 0)
                    stackView.setCustomSpacing(viewModel.coverBottomSpacing, after: imageView)
                    self.coverImageView = imageView
                }
                imageView.sd_setImage(with: url)
            } else {
                coverImageView?.isHidden = true
            }
            
            if !viewModel.content.title.isEmpty {
                let titleLabel: UILabel
                if let label = self.titleLabel {
                    label.isHidden = false
                    titleLabel = label
                } else {
                    titleLabel = UILabel()
                    titleLabel.numberOfLines = 0
                    titleLabel.font = viewModel.titleFont
                    let marginStackView = UIStackView(arrangedSubviews: [titleLabel])
                    marginStackView.axis = .horizontal
                    marginStackView.layoutMargins = viewModel.labelLayoutMargins
                    marginStackView.isLayoutMarginsRelativeArrangement = true
                    stackView.insertArrangedSubview(marginStackView, at: 1)
                    stackView.setCustomSpacing(viewModel.otherSpacing, after: marginStackView)
                    self.titleLabel = titleLabel
                }
                titleLabel.text = viewModel.content.title
            } else {
                titleLabel?.isHidden = true
            }
            
            if !viewModel.content.description.isEmpty {
                let descriptionLabel: TextLabel
                if let label = self.descriptionLabel {
                    label.isHidden = false
                    descriptionLabel = label
                } else {
                    descriptionLabel = TextLabel()
                    descriptionLabel.backgroundColor = .clear
                    descriptionLabel.textAlignment = .left
                    descriptionLabel.font = viewModel.descriptionFont
                    descriptionLabel.textColor = R.color.text_tertiary()!
                    let marginStackView = UIStackView(arrangedSubviews: [descriptionLabel])
                    marginStackView.axis = .horizontal
                    marginStackView.layoutMargins = viewModel.labelLayoutMargins
                    marginStackView.isLayoutMarginsRelativeArrangement = true
                    stackView.addArrangedSubview(marginStackView)
                    self.descriptionLabel = descriptionLabel
                }
                descriptionLabel.text = viewModel.content.description
            } else {
                descriptionLabel?.isHidden = true
            }
            
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
