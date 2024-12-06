import UIKit
import MixinServices

class AuthorizationsViewController<ContentViewController: UIViewController>: UIViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var networkIndicatorTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var networkIndicatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var networkIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var contentContainerView: UIView!
    
    let contentViewController = ContentViewController()
    
    private(set) lazy var searchContentViewController: ContentViewController = {
        let controller = ContentViewController()
        addChild(controller)
        contentContainerView.addSubview(controller.view)
        controller.view.snp.makeEdgesEqualToSuperview()
        controller.didMove(toParent: self)
        return controller
    }()
    
    init() {
        let nib = R.nib.authorizationsView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.addTarget(self, action: #selector(search(_:)), for: .editingChanged)
        searchBoxView.textField.rightViewMode = .always
        
        addChild(contentViewController)
        contentContainerView.addSubview(contentViewController.view)
        contentViewController.view.snp.makeEdgesEqualToSuperview()
        contentViewController.didMove(toParent: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }
    
    func reloadData() {
        
    }
    
    func updateViews(with keyword: String) {
        
    }
    
    @objc func search(_ textField: UITextField) {
        guard textField.markedTextRange == nil else {
            return
        }
        let keyword = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        updateViews(with: keyword)
    }
    
}
