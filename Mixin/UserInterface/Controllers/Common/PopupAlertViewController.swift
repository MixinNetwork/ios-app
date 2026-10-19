import UIKit

final class PopupAlertViewController: UIViewController {
    
    private let alertTitle: String
    private let message: String
    private let buttonTitle: String
    private let presentationManager = PopupPresentationManager()
    
    init(
        title: String,
        description: String,
        buttonTitle: String,
    ) {
        self.alertTitle = title
        self.message = description
        self.buttonTitle = buttonTitle
        super.init(nibName: nil, bundle: nil)
        transitioningDelegate = presentationManager
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = R.color.background()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 13
        
        let titleLabel = UILabel()
        titleLabel.text = alertTitle
        titleLabel.font = .scaledFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = R.color.text()
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits.insert(.header)
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.5
        paragraph.alignment = .center
        let descriptionLabel = UILabel()
        descriptionLabel.attributedText = NSAttributedString(
            string: message,
            attributes: [
                .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
                .foregroundColor: R.color.text_secondary()!,
                .paragraphStyle: paragraph,
            ]
        )
        descriptionLabel.numberOfLines = 0
        descriptionLabel.adjustsFontForContentSizeCategory = true
        
        var attributes = AttributeContainer()
        attributes.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 16, weight: .medium)
        )
        var configuration = UIButton.Configuration.filled()
        configuration.attributedTitle = AttributedString(buttonTitle, attributes: attributes)
        configuration.baseBackgroundColor = R.color.theme()
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 12,
            leading: 0,
            bottom: 11,
            trailing: 0,
        )
        let button = UIButton(configuration: configuration)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        
        for subview in [titleLabel, descriptionLabel, button] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 42),
            titleLabel.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 30),
            titleLabel.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -30),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            button.topAnchor.constraint(greaterThanOrEqualTo: descriptionLabel.bottomAnchor, constant: 10),
            button.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 36),
            button.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -36),
            button.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -30),
        ])
        let buttonSpacing = button.topAnchor.constraint(
            equalTo: descriptionLabel.bottomAnchor,
            constant: 68,
        )
        buttonSpacing.priority = .defaultLow
        buttonSpacing.isActive = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePreferredContentSizeHeight()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreferredContentSizeHeight()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @objc private func close(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
    private func updatePreferredContentSizeHeight() {
        guard let superview = view.superview else {
            return
        }
        let sizeToFit = CGSize(
            width: superview.bounds.width,
            height: UIView.layoutFittingExpandedSize.height,
        )
        let height = view.systemLayoutSizeFitting(
            sizeToFit,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel,
        ).height
        let maxHeight = superview.bounds.height - superview.safeAreaInsets.top
        let preferredHeight = min(maxHeight, height)
        if preferredContentSize.height != preferredHeight {
            preferredContentSize.height = preferredHeight
        }
    }
    
}

extension PopupAlertViewController {
    
    static func perpsMargin() -> PopupAlertViewController {
        PopupAlertViewController(
            title: R.string.localizable.margin(),
            description: R.string.localizable.perps_margin_description(),
            buttonTitle: R.string.localizable.got_it(),
        )
    }
    
}
