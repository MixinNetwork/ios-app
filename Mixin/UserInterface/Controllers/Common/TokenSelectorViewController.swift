import UIKit

class TokenSelectorViewController: UIViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var trimmedKeyword: String {
        (searchBoxView.textField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    init() {
        let nib = R.nib.tokenSelectorView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.rightViewMode = .always
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_asset()
        cancelButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 20)
        cancelButton.setTitle(R.string.localizable.cancel(), for: .normal)
    }
    
    @IBAction func cancel(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
}
