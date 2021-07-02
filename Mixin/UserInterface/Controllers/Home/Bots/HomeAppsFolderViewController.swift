import UIKit

protocol HomeAppsFolderViewControllerDelegate: AnyObject {
    
    func openAnimationWillStart(on viewController: HomeAppsFolderViewController)
    func didChange(name: String, on viewController: HomeAppsFolderViewController)
    func didSelect(app: Bot, on viewController: HomeAppsFolderViewController)
    func didEnterEditingMode(on viewController: HomeAppsFolderViewController)
    func didBeginFolderDragOut(withTransfer transfer: HomeAppsDragInteractionTransfer, on viewController: HomeAppsFolderViewController)
    func dismissAnimationWillStart(currentPage: Int, updatedPages: [[Bot]], on viewController: HomeAppsFolderViewController)
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
    var folder: BotFolder!
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
        homeAppsManager = HomeAppsManager(isHome: false, viewController: self, candidateCollectionView: collectionView, items: folder.pages)
        homeAppsManager.delegate = self
        if homeAppsManager.items.count == 1 {
            pageControl.isHidden = true
        } else {
            pageControl.alpha = 0
            pageControl.isHidden = false
            pageControl.numberOfPages = homeAppsManager.items.count
        }
        if let transfer = dragInteractionTransfer {
            homeAppsManager.perform(transfer: transfer)
        }
        if isEditing {
            let indexPath = IndexPath(item: currentPage, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        }
        dragInteractionTransfer = nil
        prepareForAnimateIn()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
        if isEditing {
            homeAppsManager.enterEditingMode(suppressHaptic: true)
        }
    }
    
    @IBAction func dismiss() {
        textField.resignFirstResponder()
        homeAppsManager.leaveEditingMode()
        delegate?.dismissAnimationWillStart(currentPage: pageControl.currentPage, updatedPages: homeAppsManager.items as! [[Bot]], on: self)
        animateOut()
    }
    
}

extension HomeAppsFolderViewController {
    
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
        delegate?.openAnimationWillStart(on: self)
        UIView.animate(withDuration: 0.5) {
            UIView.setAnimationCurve(.overdamped)
            self.view.layoutIfNeeded()
            self.textField.alpha = 1
            self.containerView.transform = CGAffineTransform.identity
            self.containerView.alpha = 1
            self.homeAppsManager.updateFolderDragOutFlags()
            self.backgroundView.effect = .regularBlur
        } completion: { _ in
            self.openAnimationDidEnd?()
            self.pageControl.alpha = 1
            if self.isEditing {
                self.enterTextFieldEditingMode()
                if self.startInRename {
                    self.textField.becomeFirstResponder()
                    self.textField.selectAll(nil)
                }
            }
        }
    }
    
    private func animateOut() {
        UIView.animate(withDuration: 0.5) {
            UIView.setAnimationCurve(.overdamped)
            self.view.layoutIfNeeded()
            self.textField.alpha = 0
            self.leaveTextFieldEditingMode()
            self.containerView.transform = CGAffineTransform.transform(rect: self.containerView.frame, to: self.sourceFrame)
            self.containerView.alpha = 0
            self.backgroundView.effect = nil
        } completion: { _ in
            self.delegate?.dismissAnimationDidFinish(on: self)
            self.homeAppsManager = nil
        }
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
    
    func didBeginFolderDragOut(transfer: HomeAppsDragInteractionTransfer, on manager: HomeAppsManager) {
        dismiss()
        delegate?.didBeginFolderDragOut(withTransfer: transfer, on: self)
    }
    
    func didSelect(app: Bot, on manager: HomeAppsManager) {
        delegate?.didSelect(app: app, on: self)
    }
    
    func didUpdateItems(on manager: HomeAppsManager) {}
    func collectionViewDidScroll(_ collectionView: UICollectionView, on manager: HomeAppsManager) {}
    
}

extension HomeAppsFolderViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if !textField.hasText {
            textField.text = self.folder.name
        } else if let text = textField.text {
            folder.name = text
            delegate?.didChange(name: text, on: self)
        }
        return true
    }
    
}
