import UIKit

class SearchConversationViewController: UIViewController {
    
    @IBOutlet weak var navigationTitleLabel: UILabel!
    @IBOutlet weak var navigationSubtitleLabel: UILabel!
    @IBOutlet weak var navigationIconView: NavigationAvatarIconView!
    @IBOutlet weak var tableView: UITableView!
    
    var conversationId = ""
    var keyword = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(R.nib.searchResultCell)
    }
    
}
