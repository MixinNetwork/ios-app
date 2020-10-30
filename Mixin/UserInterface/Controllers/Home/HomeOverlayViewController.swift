import UIKit

class HomeOverlayViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    
    let horizontalContentMargin: CGFloat = 20
    let verticalContentMargin: CGFloat = 12
    let contentViewVerticalShadowOffset: CGFloat = 4
    
    private(set) var panningController: ViewPanningController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.18
        panningController = ViewPanningController(view: view)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.shadowPath = CGPath(roundedRect: contentView.frame.offsetBy(dx: 0, dy: contentViewVerticalShadowOffset),
                                       cornerWidth: contentView.layer.cornerRadius,
                                       cornerHeight: contentView.layer.cornerRadius,
                                       transform: nil)
    }
    
    func updateViewSize() {
        view.layoutIfNeeded()
        view.bounds.size = CGSize(width: contentView.frame.width + horizontalContentMargin,
                                  height: contentView.frame.height + verticalContentMargin)
    }
    
}
