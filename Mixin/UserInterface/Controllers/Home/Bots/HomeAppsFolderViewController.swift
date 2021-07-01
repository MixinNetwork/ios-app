import UIKit

protocol HomeAppsFolderViewControllerDelegate: AnyObject {
    
}

class HomeAppsFolderViewController: UIViewController {
    
    weak var delegate: HomeAppsFolderViewControllerDelegate?
    
    @IBOutlet weak var textFieldContainer: UIView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var clearButton: UIButton!
    
    @IBOutlet weak var blurView: UIVisualEffectView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var pageControl: UIPageControl!
    
    var openAnimationDidEnd: (() -> Void)?
    var folder: BotFolder!
    var sourcePoint: CGPoint!
    var startInRename: Bool = false
    var currentPage: Int = 0
    var dragInteractionTransfer: HomeAppsDragInteractionTransfer?
    
    private var homeAppsManager: HomeAppsManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //homeAppsManager = HomeAppsManager(isHome: false, viewController: self, candidateCollectionView: collectionView)
        //homeAppsManager.delegate = self
    }
    
}

extension HomeAppsFolderViewController: HomeAppsManagerDelegate {
    
    func didUpdateItems(on manager: HomeAppsManager) {}
    func didUpdate(pageCount: Int, on manager: HomeAppsManager) {}
    func didEnterEditingMode(on manager: HomeAppsManager) {}
    func didBeginFolderDragOut(transfer: HomeAppsDragInteractionTransfer, on manager: HomeAppsManager) {}
    func didSelect(app: Bot, on manager: HomeAppsManager) {}
    
    
}
