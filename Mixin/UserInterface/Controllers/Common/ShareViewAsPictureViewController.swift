import UIKit

class ShareViewAsPictureViewController: UIViewController {
    
    @IBOutlet weak var layoutWrapperView: UIView!
    @IBOutlet weak var closeButtonEffectView: UIVisualEffectView!
    @IBOutlet weak var actionButtonTrayView: UIView!
    @IBOutlet weak var actionButtonBackgroundView: UIVisualEffectView!
    @IBOutlet weak var actionButtonStackView: UIStackView!
    
    let contentViewCornerRadius: CGFloat = 12
    
    var contentView: UIView!
    
    init() {
        let nib = R.nib.shareViewAsPictureView
        super.init(nibName: nib.name, bundle: nib.bundle)
        modalPresentationStyle = .custom
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let view = view as? TouchEventBypassView {
            view.exception = layoutWrapperView
        }
        loadContentView()
        view.insertSubview(contentView, at: 0)
        contentView.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(layoutWrapperView)
            make.bottom.equalTo(actionButtonTrayView.snp.top).offset(-12)
        }
        contentView.layer.cornerRadius = contentViewCornerRadius
        contentView.layer.masksToBounds = true
        addActionButton(
            icon: R.image.web.ic_action_share(),
            text: R.string.localizable.share()
        ) { button in
            button.addTarget(self, action: #selector(share(_:)), for: .touchUpInside)
        }
        addActionButton(
            icon: R.image.web.ic_action_copy(),
            text: R.string.localizable.link()
        ) { button in
            button.addTarget(self, action: #selector(copyLink(_:)), for: .touchUpInside)
        }
        addActionButton(
            icon: R.image.action_save(),
            text: R.string.localizable.save()
        ) { button in
            button.addTarget(self, action: #selector(savePhoto(_:)), for: .touchUpInside)
        }
    }
    
    func loadContentView() {
        contentView = UIView()
    }
    
    @IBAction func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc func share(_ sender: Any) {
        
    }
    
    @objc func copyLink(_ sender: Any) {
        
    }
    
    @objc func savePhoto(_ sender: Any) {
        
    }
    
    private func addActionButton(icon: UIImage?, text: String, config: (UIButton) -> Void) {
        let iconTrayView = UIImageView(image: R.image.explore.action_tray())
        let label = UILabel()
        label.textColor = R.color.text()
        label.text = text
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .center
        let stackView = UIStackView(arrangedSubviews: [iconTrayView, label])
        stackView.axis = .vertical
        stackView.spacing = 8
        actionButtonStackView.addArrangedSubview(stackView)
        
        let iconView = UIImageView(image: icon?.withRenderingMode(.alwaysTemplate))
        iconView.tintColor = R.color.text()
        actionButtonTrayView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.center.equalTo(iconTrayView.snp.center)
        }
        
        let button = UIButton()
        config(button)
        actionButtonTrayView.addSubview(button)
        button.snp.makeConstraints { make in
            make.edges.equalTo(stackView)
        }
    }
    
}
