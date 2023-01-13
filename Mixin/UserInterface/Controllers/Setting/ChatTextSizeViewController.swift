import UIKit

class ChatTextSizeViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var systemTextSizeSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
    }

    class func instance() -> UIViewController {
        let vc = R.storyboard.setting.chat_text_size()!
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.background_preview())
    }
    
}
