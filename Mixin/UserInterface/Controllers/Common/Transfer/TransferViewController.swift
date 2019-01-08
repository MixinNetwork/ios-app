import UIKit
import SwiftMessages

protocol TransferViewControllerDelegate: class {
    func transferViewControllerWillPresentPaymentConfirmation(_ viewController: TransferViewController)
}

class TransferViewController: UIViewController {
    
    @IBOutlet weak var backgroundButton: UIView!
    @IBOutlet weak var parametersGrabbingWrapperView: UIView!
    @IBOutlet weak var confirmationContainerView: UIView!
    
    @IBOutlet weak var parametersGrabbingWrapperViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var confirmationContainerViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var showParametersConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideParametersConstraint: NSLayoutConstraint!
    @IBOutlet weak var showConfirmationConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideConfirmationConstraint: NSLayoutConstraint!
    
    weak var delegate: TransferViewControllerDelegate?
    
    var context: PaymentContext!
    
    private let animationDuration: TimeInterval = 0.5
    
    private var parametersViewController: TransferParametersViewController!
    private var keyboardFrame = CGRect.zero
    
    private lazy var paymentViewController: PaymentConfirmationViewController = {
        let vc = PaymentConfirmationViewController.instance()
        vc.delegate = self
        addChild(vc)
        confirmationContainerView.addSubview(vc.view)
        vc.view.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        vc.didMove(toParent: self)
        return vc
    }()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    static func instance(user: UserItem, asset: AssetItem?) -> TransferViewController {
        let vc = Storyboard.common.instantiateViewController(withIdentifier: "transfer") as! TransferViewController
        vc.modalPresentationStyle = .overCurrentContext
        vc.transitioningDelegate = vc
        vc.context = PaymentContext(category: .transfer(user), asset: asset)
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateWrapperViewsHeight()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let destination = segue.destination as? TransferParametersViewController {
            parametersViewController = destination
        }
    }
    
    override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)
        if (container as? UIViewController) == paymentViewController {
            confirmationContainerViewHeightConstraint.constant = container.preferredContentSize.height
        }
    }
    
    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateWrapperViewsHeight()
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        keyboardFrame = endFrame
    }
    
    func confirmPayment() {
        delegate?.transferViewControllerWillPresentPaymentConfirmation(self)
        paymentViewController.updateKeyboardPlaceHolderHeight(keyboardFrame: keyboardFrame)
        paymentViewController.context = context
        if paymentViewController.biometricAuthIsAvailable {
            UIApplication.shared.resignFirstResponder()
        } else {
            paymentViewController.pinField.becomeFirstResponder()
        }
        showConfirmationConstraint.priority = .defaultHigh
        hideConfirmationConstraint.priority = .defaultLow
        showParametersConstraint.priority = .defaultLow
        hideParametersConstraint.priority = .defaultHigh
        UIView.animate(withDuration: animationDuration, animations: {
            UIView.setAnimationCurve(.overdamped)
            self.view.layoutIfNeeded()
        })
    }
    
    private func updateWrapperViewsHeight() {
        let windowHeight = AppDelegate.current.window!.frame.height
        let height = windowHeight - view.compatibleSafeAreaInsets.top
        parametersGrabbingWrapperViewHeightConstraint.constant = height
    }
    
}

extension TransferViewController: PaymentConfirmationDelegate {
    
    func paymentConfirmationViewController(_ viewController: PaymentConfirmationViewController, paymentDidFinishedWithError error: Error?) {
        if let error = error {
            dismiss(animated: true, completion: nil)
            SwiftMessages.showToast(message: error.localizedDescription, backgroundColor: .hintRed)
        } else {
            AppDelegate.current.window?.endEditing(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
}

extension TransferViewController: UIViewControllerTransitioningDelegate {
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }
    
}

extension TransferViewController: UIViewControllerAnimatedTransitioning {
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return animationDuration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isBeingPresented {
            view.frame = transitionContext.finalFrame(for: self)
            transitionContext.containerView.addSubview(view)
            view.layoutIfNeeded()
            showParametersConstraint.priority = .defaultHigh
            hideParametersConstraint.priority = .defaultLow
            UIView.animate(withDuration: transitionDuration(using: transitionContext), animations: {
                UIView.setAnimationCurve(.overdamped)
                self.view.layoutIfNeeded()
                self.backgroundButton.alpha = 1
            }) { (_) in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        } else if isBeingDismissed {
            hideParametersConstraint.priority = .defaultHigh
            showParametersConstraint.priority = .defaultLow
            hideConfirmationConstraint.priority = .defaultHigh
            showConfirmationConstraint.priority = .defaultLow
            UIView.animate(withDuration: transitionDuration(using: transitionContext), animations: {
                UIView.setAnimationCurve(.overdamped)
                self.view.layoutIfNeeded()
                self.backgroundButton.alpha = 0
            }) { (_) in
                self.view.removeFromSuperview()
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        }
    }
    
}
