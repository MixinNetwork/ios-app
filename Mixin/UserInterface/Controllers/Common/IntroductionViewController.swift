import UIKit

class IntroductionViewController: UIViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentTextView: UITextView!
    @IBOutlet weak var actionStackView: UIStackView!
    @IBOutlet weak var actionButton: StyledButton!
    
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentLabelTopConstraint: NSLayoutConstraint!
    
    init() {
        let nib = R.nib.introductionView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 18, weight: .semibold), adjustForContentSize: true)
        contentTextView.textContainerInset = .zero
        contentTextView.textContainer.lineFragmentPadding = 0
        actionButton.style = .filled
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.isScrollEnabled = scrollView.contentSize.height > scrollView.frame.height
    }
    
}
