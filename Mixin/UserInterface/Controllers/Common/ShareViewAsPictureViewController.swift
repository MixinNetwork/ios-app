import UIKit

class ShareViewAsPictureViewController<ContentView: UIView>: UIViewController {
    
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var layoutWrapperView: UIView!
    @IBOutlet weak var contentWrapperView: UIView!
    @IBOutlet weak var actionButtonTrayView: UIView!
    @IBOutlet weak var actionButtonBackgroundView: UIVisualEffectView!
    @IBOutlet weak var actionButtonStackView: UIStackView!
    
    @IBOutlet weak var closeButtonWrapperTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var layoutWrapperHeightConstraint: NSLayoutConstraint!
    
    let contentView: ContentView
    
    private let contentSize: CGSize
    private let contentViewCornerRadius: CGFloat = 12
    
    private var contentWrapperFrameObservation: NSKeyValueObservation?
    
    init(contentView: ContentView, size: CGSize) {
        self.contentView = contentView
        self.contentSize = size
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
        
        contentWrapperView.snp.makeConstraints { make in
            make.width.equalTo(contentWrapperView.snp.height)
                .multipliedBy(contentSize.width / contentSize.height)
                .priority(.medium)
        }
        contentWrapperView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(contentSize)
        }
        contentView.layer.cornerRadius = contentViewCornerRadius
        contentView.layer.masksToBounds = true
        contentWrapperFrameObservation = view.observe(
            \.frame,
             options: [.new]
        ) { [weak self] (_,_)  in
            self?.resizeContentView()
        }
        resizeContentView()
        
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
    
    @IBAction func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc func share(_ sender: Any) {
        
    }
    
    @objc func copyLink(_ sender: Any) {
        
    }
    
    @objc func savePhoto(_ sender: Any) {
        
    }
    
    func makeImage() -> UIImage {
        let canvas = contentView.bounds
        let renderer = UIGraphicsImageRenderer(bounds: canvas)
        contentView.layer.cornerRadius = 0
        let image = renderer.image { context in
            contentView.drawHierarchy(in: canvas, afterScreenUpdates: true)
        }
        contentView.layer.cornerRadius = contentViewCornerRadius
        return image
    }
    
    private func resizeContentView() {
        let scaleX = contentWrapperView.frame.width / contentSize.width
        let scaleY = contentWrapperView.frame.height / contentSize.height
        let scale = min(scaleX, scaleY)
        contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
        let horizontalMargin = contentWrapperView.frame.width * (1 - min(1, scale))
        closeButtonWrapperTrailingConstraint.constant = 2 + horizontalMargin / 2
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
