import UIKit

protocol HomeAppsFolderViewControllerDelegate: AnyObject {
    
}

class HomeAppsFolderViewController: UIViewController {
    
    weak var delegate: HomeAppsFolderViewControllerDelegate?
    
    var folder: BotFolder!
    var sourcePoint: CGPoint!
    var startInRename: Bool = false
    var currentPage: Int = 0
    var dragInteractionTransfer: HomeAppsDragInteractionTransfer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
}
