import UIKit

class BaseViewController: UIViewController {


    @IBAction func leftTappedAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }


}
