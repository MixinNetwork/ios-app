import UIKit

class AboutContainerViewController: UIViewController {

    @IBOutlet weak var versionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        versionLabel.text = Bundle.main.shortVersion + "(\(Bundle.main.bundleVersion))"
    }
    
    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    class func instance() -> UIViewController {
        return Storyboard.setting.instantiateViewController(withIdentifier: "about")
    }

}
