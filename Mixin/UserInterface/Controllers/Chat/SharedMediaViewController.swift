import UIKit

protocol SharedMediaContentViewController: class {
    var conversationId: String! { get set }
}

class SharedMediaViewController: UIViewController {
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var segmentedControl: SegmentedControl!
    
    var conversationId: String?
    
    private lazy var mediaViewController = R.storyboard.chat.shared_media_media()!
    private lazy var audioViewController = SharedMediaAudioTableViewController()
    private lazy var dataViewController = SharedMediaDataTableViewController()
    
    private var contentViewController: UIViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        segmentedControl.itemTitles = [
            R.string.localizable.chat_media_category_media(),
            R.string.localizable.chat_media_category_audio(),
            R.string.localizable.chat_media_category_file()
        ]
        load(child: mediaViewController)
    }
    
    @IBAction func changeSegmentAction(_ sender: Any) {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            load(child: mediaViewController)
        case 1:
            load(child: audioViewController)
        default:
            load(child: dataViewController)
        }
    }
    
    private func load(child: UIViewController & SharedMediaContentViewController) {
        if let current = contentViewController {
            current.willMove(toParent: nil)
            current.view.removeFromSuperview()
            current.removeFromParent()
        }
        child.conversationId = conversationId
        addChild(child)
        containerView.addSubview(child.view)
        child.view.snp.makeEdgesEqualToSuperview()
        child.didMove(toParent: self)
        contentViewController = child
    }
    
}
