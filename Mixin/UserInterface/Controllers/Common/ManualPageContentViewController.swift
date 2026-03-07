import UIKit
import SwiftUI

final class ManualPageContentViewController: UIViewController {
    
    protocol Delegate: AnyObject {
        func manualPageContentViewController(_ controller: ManualPageContentViewController, didNavigateTo index: Int)
    }
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var pageSwitchingView: UIView!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    
    weak var delegate: Delegate?
    
    var isReusable: Bool {
        parent == nil
    }
    
    private(set) var index: Int
    
    private var page: ManualViewController.Page
    private var previousTitle: String?
    private var nextTitle: String?
    
    private weak var hostingController: UIHostingController<AnyView>!
    
    init(
        index: Int,
        page: ManualViewController.Page,
        previousTitle: String?,
        nextTitle: String?
    ) {
        self.index = index
        self.page = page
        self.previousTitle = previousTitle
        self.nextTitle = nextTitle
        let nib = R.nib.manualPageContentView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let hostingController = UIHostingController(rootView: page.view)
        addChild(hostingController)
        contentView.addSubview(hostingController.view)
        hostingController.view.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.lessThanOrEqualTo(pageSwitchingView.snp.top)
        }
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
        if #available(iOS 16.0, *) {
            hostingController.sizingOptions = [.intrinsicContentSize]
        }
        updatePageSwitchingButtons(
            previousTitle: previousTitle,
            nextTitle: nextTitle
        )
        for button: UIButton in [previousButton, nextButton] {
            button.titleLabel?.adjustsFontForContentSizeCategory = true
        }
    }
    
    @IBAction func goPrevious(_ sender: Any) {
        delegate?.manualPageContentViewController(self, didNavigateTo: index - 1)
    }
    
    @IBAction func goNext(_ sender: Any) {
        delegate?.manualPageContentViewController(self, didNavigateTo: index + 1)
    }
    
    func load(
        index: Int,
        page: ManualViewController.Page,
        previousTitle: String?,
        nextTitle: String?
    ) {
        self.index = index
        hostingController.rootView = page.view
        updatePageSwitchingButtons(
            previousTitle: previousTitle,
            nextTitle: nextTitle
        )
        scrollView.setContentOffset(.zero, animated: false)
    }
    
    private func updatePageSwitchingButtons(
        previousTitle: String?,
        nextTitle: String?
    ) {
        var attributes = AttributeContainer()
        attributes.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 16, weight: .medium)
        )
        if let previousTitle {
            previousButton.configuration?.attributedTitle = AttributedString(previousTitle, attributes: attributes)
            previousButton.isHidden = false
        } else {
            previousButton.isHidden = true
        }
        if let nextTitle {
            nextButton.configuration?.attributedTitle = AttributedString(nextTitle, attributes: attributes)
            nextButton.isHidden = false
        } else {
            nextButton.isHidden = true
        }
    }
    
}
