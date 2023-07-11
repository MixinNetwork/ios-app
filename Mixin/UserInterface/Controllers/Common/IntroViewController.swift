import UIKit

class IntroViewController: UIViewController {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionTextLabel: TextLabel!
    @IBOutlet weak var noticeTextView: UITextView!
    @IBOutlet weak var nextButton: RoundedButton!
    @IBOutlet weak var actionDescriptionLabel: UILabel!
    
    @IBOutlet weak var noticeTextViewHeightConstraint: NSLayoutConstraint!
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    init() {
        let nib = R.nib.introView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentStackView.setCustomSpacing(24, after: iconImageView)
        descriptionTextLabel.delegate = self
        noticeTextView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 14)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if noticeTextViewHeightConstraint.constant != noticeTextView.contentSize.height {
            noticeTextViewHeightConstraint.constant = noticeTextView.contentSize.height
        }
    }
    
    @IBAction func continueToNext(_ sender: RoundedButton) {
        
    }
    
}

extension IntroViewController: CoreTextLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    func coreTextLabel(_ label: CoreTextLabel, didLongPressOnURL url: URL) {
        
    }
    
}
