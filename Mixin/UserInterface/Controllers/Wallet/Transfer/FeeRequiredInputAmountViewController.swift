import UIKit
import MixinServices

class FeeRequiredInputAmountViewController: TokenConsumingInputAmountViewController {
    
    enum FeeStyle {
        case normal
        case waived
    }
    
    private(set) weak var feeStackView: UIStackView?
    private(set) weak var addFeeButton: UIButton?
    private(set) weak var feeActivityIndicator: ActivityIndicatorView?
    private(set) weak var feeWaivedButton: UIButton?
    private(set) weak var changeFeeButton: UIButton?
    
    private lazy var feeAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
        var outgoing = incoming
        outgoing.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 14)
        )
        outgoing.foregroundColor = R.color.text_tertiary()
        outgoing.strikethroughStyle = .none
        outgoing.inlinePresentationIntent = nil
        return outgoing
    }
    
    private lazy var feeFreeAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
        var outgoing = incoming
        outgoing.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 14)
        )
        outgoing.foregroundColor = R.color.text_tertiary()
        outgoing.strikethroughColor = R.color.text_tertiary()
        outgoing.strikethroughStyle = .single
        outgoing.inlinePresentationIntent = .strikethrough
        return outgoing
    }
    
    func addFeeView() {
        let titleLabel = InsetLabel()
        titleLabel.contentInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        titleLabel.text = R.string.localizable.network_fee()
        titleLabel.textColor = R.color.text_tertiary()
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        
        let activityIndicator = ActivityIndicatorView()
        activityIndicator.style = .custom(diameter: 16, lineWidth: 2)
        activityIndicator.tintColor = R.color.icon_tint_tertiary()
        activityIndicator.hidesWhenStopped = true
        activityIndicator.isAnimating = true
        self.feeActivityIndicator = activityIndicator
        
        var config: UIButton.Configuration = .plain()
        config.baseBackgroundColor = .clear
        config.imagePlacement = .trailing
        config.imagePadding = 14
        config.titleTextAttributesTransformer = feeAttributesTransformer
        config.title = "0"
        config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 5, bottom: 7, trailing: 12)
        let changeFeeButton = UIButton(configuration: config)
        changeFeeButton.tintColor = R.color.icon_tint_tertiary()
        changeFeeButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        changeFeeButton.alpha = 0
        self.changeFeeButton = changeFeeButton
        
        let feeStackView = UIStackView(
            arrangedSubviews: [titleLabel, activityIndicator, changeFeeButton]
        )
        feeStackView.axis = .horizontal
        feeStackView.alignment = .center
        
        accessoryStackView.insertArrangedSubview(feeStackView, at: 0)
        feeStackView.snp.makeConstraints { make in
            make.width.equalTo(view.snp.width).offset(-56)
        }
        self.feeStackView = feeStackView
    }
    
    func updateFeeView(style: FeeStyle) {
        switch style {
        case .normal:
            changeFeeButton?.configuration?.titleTextAttributesTransformer = feeAttributesTransformer
            feeWaivedButton?.isHidden = true
        case .waived:
            changeFeeButton?.configuration?.titleTextAttributesTransformer = feeFreeAttributesTransformer
            if let feeWaivedButton {
                feeWaivedButton.isHidden = false
            } else {
                var config: UIButton.Configuration = .filled()
                config.baseBackgroundColor = R.color.background_tinted()
                var attributes = AttributeContainer()
                attributes.font = UIFont.preferredFont(forTextStyle: .caption1)
                attributes.foregroundColor = .white
                config.attributedTitle = AttributedString(
                    R.string.localizable.free(),
                    attributes: attributes
                )
                config.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
                let button = UIButton(configuration: config)
                button.addTarget(
                    self,
                    action: #selector(presentCrossWalletTransactionFreeDescription(_:)),
                    for: .touchUpInside
                )
                feeStackView?.insertArrangedSubview(button, at: 2)
                button.titleLabel?.adjustsFontForContentSizeCategory = true
                feeWaivedButton = button
            }
        }
    }
    
    @objc private func presentCrossWalletTransactionFreeDescription(_ sender: Any) {
        let introduction = CrossWalletTransactionFreeIntroductionViewController()
        present(introduction, animated: true)
    }
    
}

extension FeeRequiredInputAmountViewController {
    
    func insertAddFeeButton(symbol: String) {
        if addFeeButton == nil {
            var config: UIButton.Configuration = .plain()
            config.baseBackgroundColor = .clear
            config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 5, bottom: 7, trailing: 5)
            let button = UIButton(configuration: config)
            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            button.addTarget(self, action: #selector(addFee(_:)), for: .touchUpInside)
            feeStackView?.insertArrangedSubview(button, at: 1)
            addFeeButton = button
        }
        addFeeButton?.configuration?.attributedTitle = AttributedString(
            R.string.localizable.add_token(symbol),
            attributes: addTokenAttributes
        )
    }
    
    func removeAddFeeButton() {
        addFeeButton?.removeFromSuperview()
    }
    
    @objc func addFee(_ sender: Any) {
        
    }
    
}
