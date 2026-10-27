import UIKit

final class GalleryTransitionViewController: UIViewController {
    
    override var prefersStatusBarHidden: Bool {
        true
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        .none
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }
    
    let backgroundView = UIView()
    
    init(backgroundAlpha: CGFloat) {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalPresentationCapturesStatusBarAppearance = true
        backgroundView.backgroundColor = .black
        backgroundView.alpha = backgroundAlpha
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        backgroundView.frame = view.bounds
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backgroundView)
    }
    
}
