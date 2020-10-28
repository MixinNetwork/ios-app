import UIKit

class HomeOverlayViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    
    let contentMargin: CGFloat = 20
    
    private(set) var panningController: ViewPanningController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.18
        panningController = ViewPanningController(view: view)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.shadowPath = CGPath(roundedRect: contentView.frame.offsetBy(dx: 0, dy: 4),
                                       cornerWidth: contentView.layer.cornerRadius,
                                       cornerHeight: contentView.layer.cornerRadius,
                                       transform: nil)
    }
    
    func updateViewSize() {
        view.layoutIfNeeded()
        view.bounds.size = CGSize(width: contentView.frame.width + contentMargin,
                                  height: contentView.frame.height + contentMargin)
    }
    
}
