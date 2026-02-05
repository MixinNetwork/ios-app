import UIKit

final class MnemonicsQRCodeViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var codeView: ModernQRCodeView!
    @IBOutlet weak var doneButton: UIButton!
    
    private let string: String
    
    init(string: String) {
        self.string = string
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentView.layer.cornerRadius = 13
        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        contentView.layer.masksToBounds = true
        contentStackView.setCustomSpacing(28, after: descriptionLabel)
        contentStackView.setCustomSpacing(20, after: codeView)
        titleLabel.text = R.string.localizable.backup_mnemonic_phrase()
        descriptionLabel.text = R.string.localizable.scan_code_description()
        codeView.setDefaultCornerCurve()
        doneButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.done(),
            attributes: .init([
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor.white,
            ])
        )
        doneButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePreferredContentSizeHeight()
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        codeView.setContent(string, size: codeView.bounds.size)
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @IBAction func saveToAlbum(_ sender: Any) {
        guard let image = codeView.imageView.image else {
            return
        }
        PhotoLibrary.saveImage(source: .image(image)) { alert in
            self.present(alert, animated: true)
        }
    }
    
    @IBAction func done(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    private func updatePreferredContentSizeHeight() {
        view.layoutIfNeeded()
        let fittingSize = CGSize(
            width: contentView.bounds.width,
            height: UIView.layoutFittingExpandedSize.height
        )
        preferredContentSize.height = contentView.systemLayoutSizeFitting(fittingSize).height
    }
    
}
