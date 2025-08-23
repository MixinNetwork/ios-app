import UIKit

final class TIPQuizAnswerViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var finishButton: UIButton!
    
    var onTryAgain: (() -> Void)?
    
    private let answer: TIPQuizAnswer
    private let popupManager = PopupPresentationManager()
    
    init(answer: TIPQuizAnswer) {
        self.answer = answer
        let nib = R.nib.tipQuizAnswerView
        super.init(nibName: nib.name, bundle: nib.bundle)
        modalPresentationStyle = .custom
        transitioningDelegate = popupManager
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.layer.cornerRadius = 13
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        
        var finishButtonAttributes = AttributeContainer()
        finishButtonAttributes.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 16, weight: .medium)
        )
        finishButtonAttributes.foregroundColor = .white

        switch answer {
        case .wrong:
            imageView.image = R.image.tip_quiz_wrong()
            titleLabel.text = R.string.localizable.tip_quiz_title_wrong()
            finishButton.configuration?.attributedTitle = AttributedString(
                R.string.localizable.try_again(),
                attributes: finishButtonAttributes
            )
        case .correct:
            imageView.image = R.image.tip_quiz_correct()
            titleLabel.text = R.string.localizable.tip_quiz_title_correct()
            finishButton.configuration?.attributedTitle = AttributedString(
                R.string.localizable.got_it(),
                attributes: finishButtonAttributes
            )
        }
        descriptionLabel.text = R.string.localizable.tip_quiz_answer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePreferredContentSizeHeight()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @IBAction func finish(_ sender: Any) {
        switch answer {
        case .wrong:
            onTryAgain?()
            presentingViewController?.dismiss(animated: true)
        case .correct:
            if let navigationController = presentingViewController as? TIPNavigationController {
                navigationController.finish()
            }
        }
    }
    
    private func updatePreferredContentSizeHeight() {
        view.layoutIfNeeded()
        let width = view.bounds.width
        let fittingSize = CGSize(width: width, height: UIView.layoutFittingExpandedSize.height)
        preferredContentSize.height = view.systemLayoutSizeFitting(fittingSize).height
    }
    
}
