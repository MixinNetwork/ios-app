import UIKit

protocol HomeAppsFolderViewControllerDelegate: AnyObject {
    
    func openAnimationWillStart(on viewController: HomeAppsFolderViewController)
    func didChange(name: String, on viewController: HomeAppsFolderViewController)
    func didSelect(app: AppModel, on viewController: HomeAppsFolderViewController)
    func didEnterEditingMode(on viewController: HomeAppsFolderViewController)
    func didBeginFolderDragOut(withTransfer transfer: HomeAppsDragInteractionTransfer, on viewController: HomeAppsFolderViewController)
    func dismissAnimationWillStart(currentPage: Int, updatedPages: [[AppModel]], on viewController: HomeAppsFolderViewController)
    func dismissAnimationDidFinish(on viewController: HomeAppsFolderViewController)
    
}

class HomeAppsFolderViewController: UIViewController {
    
    weak var delegate: HomeAppsFolderViewControllerDelegate?
    
    @IBOutlet weak var backgroundView: UIVisualEffectView!
    @IBOutlet weak var textFieldContainer: UIView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var blurView: UIVisualEffectView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var pageControl: UIPageControl!
    
    var openAnimationDidEnd: (() -> Void)?
    var folder: AppFolderModel!
    var sourceFrame: CGRect!
    var startInRename: Bool = false
    var currentPage: Int = 0
    var dragInteractionTransfer: HomeAppsDragInteractionTransfer?
    
    private var homeAppsManager: HomeAppsManager!
    private var containerViewOriginalFrame: CGRect!
    
    class func instance() -> HomeAppsFolderViewController {
        R.storyboard.home.appsFolder()!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textField.text = folder.name
        leaveTextFieldEditingMode()
        homeAppsManager = HomeAppsManager(viewController: self, candidateCollectionView: collectionView, items: folder.pages)
        homeAppsManager.delegate = self
        if homeAppsManager.items.count == 1 {
            pageControl.isHidden = true
        } else {
            pageControl.alpha = 0
            pageControl.isHidden = false
            pageControl.numberOfPages = homeAppsManager.items.count
        }
        if isEditing {
            let indexPath = IndexPath(item: currentPage, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        }
        dragInteractionTransfer = nil
        prepareForAnimateIn()
        if let transfer = dragInteractionTransfer {
            homeAppsManager.perform(transfer: transfer)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        delegate?.openAnimationWillStart(on: self)
        animateIn()
        if isEditing {
            homeAppsManager.enterEditingMode(occurHaptic: false)
        }
    }
    
    @IBAction func clearTextField(_ sender: UIButton) {
        textField.text = ""
        textField.becomeFirstResponder()
    }
    
    @IBAction func dismissAction() {
        dismiss()
    }
    
}

extension HomeAppsFolderViewController {
    
    private func dismiss(completion: (() -> Void)? = nil) {
        textField.resignFirstResponder()
        homeAppsManager.leaveEditingMode()
        delegate?.dismissAnimationWillStart(currentPage: pageControl.currentPage, updatedPages: homeAppsManager.items as! [[AppModel]], on: self)
        animateOut(completion: completion)
    }
    
    private func leaveTextFieldEditingMode() {
        textField.isEnabled = false
        clearButton.alpha = 0
        textFieldContainer.backgroundColor = textFieldContainer.backgroundColor?.withAlphaComponent(0)
    }
    
    private func enterTextFieldEditingMode() {
        textField.isEnabled = true
        clearButton.alpha = 1
        textFieldContainer.backgroundColor = textFieldContainer.backgroundColor?.withAlphaComponent(0.4)
    }
    
    private func prepareForAnimateIn() {
        view.layoutIfNeeded()
        textField.alpha = 0
        backgroundView.effect = nil
        containerViewOriginalFrame = containerView.frame
        containerView.transform = CGAffineTransform.transform(rect: containerView.frame, to: sourceFrame)
        containerView.alpha = 0
    }
    
    private func animateIn() {
        let animation = UIViewPropertyAnimator(duration: 0.35, controlPoint1: CGPoint(x: 0.37, y: 0.31), controlPoint2: CGPoint(x: 0, y: 1)) {
            self.view.layoutIfNeeded()
            self.textField.alpha = 1
            self.containerView.transform = CGAffineTransform.identity
            self.containerView.alpha = 1
            self.homeAppsManager.updateFolderDragOutFlags()
            self.backgroundView.effect = .regularBlur
        }
        animation.addCompletion { _ in
            self.openAnimationDidEnd?()
            UIViewPropertyAnimator(duration: 0.5, curve: .easeOut) {
                self.pageControl.alpha = 1
                if self.isEditing {
                    self.enterTextFieldEditingMode()
                    if self.startInRename {
                        self.textField.becomeFirstResponder()
                        self.textField.selectAll(nil)
                    }
                }
            }.startAnimation()
        }
        animation.startAnimation()
    }
    
    private func animateOut(completion: (() -> Void)?) {
        let animation = UIViewPropertyAnimator(duration: 0.35, controlPoint1: CGPoint(x: 0.37, y: 0.13), controlPoint2: CGPoint(x: 0, y: 1)) {
            self.view.layoutIfNeeded()
            self.textField.alpha = 0
            self.leaveTextFieldEditingMode()
            self.containerView.transform = CGAffineTransform.transform(rect: self.containerView.frame, to: self.sourceFrame)
            self.containerView.alpha = 0
            self.backgroundView.effect = nil
        }
        animation.addCompletion { _ in
            self.delegate?.dismissAnimationDidFinish(on: self)
            self.homeAppsManager = nil
            completion?()
        }
        animation.startAnimation()
    }
    
}

extension HomeAppsFolderViewController: HomeAppsManagerDelegate {
    
    func didUpdate(pageCount: Int, on manager: HomeAppsManager) {
        pageControl.numberOfPages = pageCount
    }
    
    func didMove(toPage page: Int, on manager: HomeAppsManager) {
        pageControl.currentPage = page
    }
    
    func didEnterEditingMode(on manager: HomeAppsManager) {
        if !isEditing {
            delegate?.didEnterEditingMode(on: self)
            isEditing = true
        }
        if pageControl.isHidden {
            pageControl.isHidden = false
            pageControl.alpha = 0
        }
        UIView.animate(withDuration: 0.25) {
            self.enterTextFieldEditingMode()
            self.pageControl.numberOfPages = self.homeAppsManager.items.count
            self.pageControl.alpha = 1
        }
    }
    
    func didLeaveEditingMode(on manager: HomeAppsManager) {
        if !textField.hasText {
            textField.text = folder.name
        } else if let text = textField.text {
            folder.name = text
            delegate?.didChange(name: text, on: self)
        }
        leaveTextFieldEditingMode()
    }
    
    func didBeginFolderDragOut(transfer: HomeAppsDragInteractionTransfer, on manager: HomeAppsManager) {
        dismissAction()
        delegate?.didBeginFolderDragOut(withTransfer: transfer, on: self)
    }
    
    func didSelect(app: AppModel, on manager: HomeAppsManager) {
        dismiss { [weak self] in
            guard let self = self else { return }
            self.delegate?.didSelect(app: app, on: self)
        }
    }
    
    func didUpdateItems(on manager: HomeAppsManager) {}
    
}

extension HomeAppsFolderViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if !textField.hasText {
            textField.text = folder.name
        } else if let text = textField.text {
            folder.name = text
            delegate?.didChange(name: text, on: self)
        }
        return true
    }
    
}
