import UIKit

class ConversationCircleEditorViewController: UIViewController {
    
    class func instance(name: String) -> UIViewController {
        let vc = ConversationCircleEditorViewController()
        let title = R.string.localizable.circle_conversation_editor_title(name)
        return ContainerViewController.instance(viewController: vc, title: title)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
}
