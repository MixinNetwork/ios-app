import UIKit

class CheckmarkPeerCell: PeerCell {
    
    override class var nib: UINib {
        return UINib(nibName: "CheckmarkPeerCell", bundle: .main)
    }
    
    override class var reuseIdentifier: String {
        return "checkmark_peer"
    }
    
    @IBOutlet weak var checkmarkView: CheckmarkView!
    
    var isForceSelected = false
    
    override func prepareForReuse() {
        super.prepareForReuse()
        isForceSelected = false
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if isForceSelected {
            checkmarkView.status = .nonSelectable
        } else {
            checkmarkView.status = selected ? .selected : .deselected
        }
    }
    
    override func makeSelectedBackgroundView() -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
}
