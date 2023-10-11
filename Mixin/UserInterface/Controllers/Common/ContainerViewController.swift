import UIKit

extension UIViewController {
    
    var container: ContainerViewController? {
        return parent as? ContainerViewController
    }

}

protocol ContainerViewControllerDelegate: AnyObject {
    
    func barLeftButtonTappedAction()

    func barRightButtonTappedAction()

    func prepareBar(rightButton: StateResponsiveButton)

    func textBarRightButton() -> String?

    func imageBarRightButton() -> UIImage?
    
    func imageBarLeftButton() -> UIImage?
    
}

extension ContainerViewControllerDelegate where Self: UIViewController {
    
    func prepareBar(rightButton: StateResponsiveButton) {

    }

    func textBarRightButton() -> String? {
        return nil
    }

    func imageBarRightButton() -> UIImage? {
        return nil
    }

    func barLeftButtonTappedAction() {
        navigationController?.popViewController(animated: true)
    }

    func barRightButtonTappedAction() {
        
    }
    
    func imageBarLeftButton() -> UIImage? {
        return nil
    }

}

class ContainerViewController: UIViewController {

    @IBOutlet weak var navigationBar: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var rightButton: StateResponsiveButton!
    @IBOutlet weak var leftButton: UIButton!
    
    @IBOutlet weak var rightButtonTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var rightButtonWidthConstraint: NSLayoutConstraint!

    weak var delegate: ContainerViewControllerDelegate?
    private(set) var viewController: UIViewController!
    private var controllerTitle = ""

    override var description: String {
        "<Mixin.ContainerViewController \(viewController.description)>"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareBarButtons()
        navigationBar.layoutIfNeeded()
        titleLabel.text = controllerTitle
        addChild(viewController)
        containerView.addSubview(viewController.view)
        viewController.view.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        viewController.didMove(toParent: self)
    }

    @IBAction func rightAction(_ sender: Any) {
        delegate?.barRightButtonTappedAction()
    }

    private func prepareBarButtons() {
        guard let delegate = self.delegate else {
            rightButtonWidthConstraint.priority = .defaultLow
            return
        }
        if let image = delegate.imageBarLeftButton() {
            leftButton.setImage(image, for: .normal)
        }
        if let text = delegate.textBarRightButton() {
            rightButton.setTitle(text, for: .normal)
            rightButton.enabledColor = .clear
            rightButton.disabledColor = .clear
            rightButton.isEnabled = false
            rightButton.setTitleColor(.lightGray, for: .disabled)
            rightButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
            rightButtonWidthConstraint.priority = .defaultLow
        } else if let image = delegate.imageBarRightButton() {
            rightButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            rightButton.setImage(image, for: .normal)
        }
        delegate.prepareBar(rightButton: rightButton)
        rightButton.saveNormalState()
    }

    func reloadRightButton() {
        guard let image = delegate?.imageBarRightButton() else {
            return
        }
        rightButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        rightButton.setImage(image, for: .normal)
    }

    func setSubtitle(subtitle: String?) {
        titleLabel.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 16, weight: .semibold))
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = false
    }

    @IBAction func backAction(_ sender: Any) {
        guard let delegate = self.delegate else {
            navigationController?.popViewController(animated: true)
            return
        }
        delegate.barLeftButtonTappedAction()
    }

    class func instance(viewController: UIViewController, title: String) -> ContainerViewController {
        let vc = R.storyboard.common.instantiateInitialViewController()!
        vc.viewController = viewController
        vc.delegate = viewController as? ContainerViewControllerDelegate
        vc.controllerTitle = title
        return vc
    }

}
