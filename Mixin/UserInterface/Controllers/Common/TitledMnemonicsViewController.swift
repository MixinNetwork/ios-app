import UIKit
import MixinServices

class TitledMnemonicsViewController: UIViewController, MnemonicsViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var inputStackView: UIStackView!
    @IBOutlet weak var footerStackView: UIStackView!
    @IBOutlet weak var actionStackView: UIStackView!
    @IBOutlet weak var confirmButton: StyledButton!
    
    @IBOutlet weak var contentViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputStackViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var footerStackViewBottomConstraint: NSLayoutConstraint!
    
    var inputFields: [MnemonicsInputField] = []
    
    init() {
        let nib = R.nib.titledMnemonicsView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        descriptionLabel.setFont(scaledFor: .monospacedDigitSystemFont(ofSize: 14, weight: .regular), adjustForContentSize: true)
        confirmButton.style = .filled
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adjustScrollViewContentInsets(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adjustScrollViewContentInsets(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @IBAction func confirm(_ sender: Any) {
        
    }
    
    @objc func adjustScrollViewContentInsets(_ notification: Notification) {
        guard var endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        endFrame = view.convert(endFrame, from: view.window)
        if notification.name == UIResponder.keyboardWillHideNotification {
            scrollView.contentInset = .zero
            contentViewHeightConstraint.priority = .defaultLow
        } else {
            scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: endFrame.height - view.safeAreaInsets.bottom, right: 0)
            contentViewHeightConstraint.constant = view.bounds.height - endFrame.height - view.safeAreaInsets.vertical
            contentViewHeightConstraint.priority = .defaultHigh
        }
        scrollView.scrollIndicatorInsets = scrollView.contentInset
        view.layoutIfNeeded()
    }
    
    func addTextInFooter(text: String) {
        let label = UILabel()
        label.textColor = R.color.text_tertiary()
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        label.numberOfLines = 0
        footerStackView.addArrangedSubview(label)
        label.text = text
    }
    
}
