import UIKit

class MinimizedPlaylistViewController: HomeOverlayViewController {
    
    @IBOutlet weak var waveView: MinimizedPlaylistWaveView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateViewSize()
    }
    
    func show() {
        view.alpha = 1
        panningController.stickViewToParentEdge(horizontalVelocity: 0, animated: true)
    }
    
    func hide() {
        view.alpha = 0
    }
    
    @IBAction func showPlaylist(_ sender: Any) {
        let vc = PlaylistViewController()
        vc.loadViewIfNeeded()
        present(vc, animated: true, completion: nil)
    }
    
}
