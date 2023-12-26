import UIKit
import MixinServices

final class HomeAppsPinTipsViewController: UIViewController {
    
    @IBOutlet weak var pinnedAppViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var candidateAppLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var appIconViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var arrowLineHeightConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let mode: HomeAppsMode = .regular
        candidateAppLeadingConstraint.constant = mode.sectionInset.left
            + mode.itemSize.width
            + mode.minimumInteritemSpacing
            + (mode.itemSize.width - HomeAppsMode.imageContainerSize.width) / 2
    }
    
    @IBAction func dismiss(_ sender: Any) {
        AppGroupUserDefaults.User.homeAppsPinTips = true
        dismiss(animated: true, completion: nil)
    }
    
}
