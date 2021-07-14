import UIKit
import MixinServices

class HomeAppsPinTipsViewController: UIViewController {
    
    var topSpace: CGFloat = 0
    
    @IBOutlet weak var pinnedAppViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var candidateAppLeadingConstraint: NSLayoutConstraint!
    @IBOutlet var pinnedAppSpaceConstraints: [NSLayoutConstraint]!
    @IBOutlet weak var lineViewTrailingConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let mode = HomeAppsMode.regular
        candidateAppLeadingConstraint.constant = mode.sectionInset.left + mode.itemSize.width + mode.minimumInteritemSpacing + (mode.itemSize.width - HomeAppsMode.imageContainerSize.width)/2
        pinnedAppSpaceConstraints.forEach({ $0.constant = HomeAppsMode.pinned.minimumInteritemSpacing })
        pinnedAppViewTopConstraint.constant = topSpace
        lineViewTrailingConstraint.constant = 3 - HomeAppsMode.pinned.itemSize.width/2
    }
    
    @IBAction func dismiss(_ sender: Any) {
        AppGroupUserDefaults.User.homeAppsPinTips = true
        dismiss(animated: true, completion: nil)
    }
    
}
