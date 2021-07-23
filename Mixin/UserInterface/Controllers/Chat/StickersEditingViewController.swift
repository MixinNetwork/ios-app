import UIKit
import MixinServices

class StickersEditingViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var stickerImageView: UIImageView!
    @IBOutlet weak var stickerEmptyHintView: UIView!
    @IBOutlet weak var stickerEmptyHintViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var stickerEmptyHintViewHeightConstraint: NSLayoutConstraint!
    
    var stickerStoreItems = [StickerStoreItem]()
    
    class func instance() -> StickersEditingViewController {
        R.storyboard.chat.my_stickers()!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        stickerImageView.tintColor = UIColor(displayP3RgbValue: 0xC0C5D4, alpha: 0.3)
        stickerEmptyHintViewTopConstraint.constant = (UIScreen.main.bounds.height - stickerEmptyHintViewHeightConstraint.constant)/7*3
        tableView.setEditing(false, animated: true)
        tableView.dragInteractionEnabled = true
        tableView.dragDelegate = self
    }
    
    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
}

extension StickersEditingViewController {
    
    private func setStickerEmptyHintHidden(_ hidden: Bool) {
        stickerEmptyHintView.isHidden = hidden
        tableView.isHidden = !hidden
    }
    
}

extension StickersEditingViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stickerStoreItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.stickers_editing, for: indexPath)!
        if indexPath.row < stickerStoreItems.count {
            cell.stickerStoreItem = stickerStoreItems[indexPath.row]
            cell.onDeleteSticker = {
                tableView.performBatchUpdates {
                    self.stickerStoreItems.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                } completion: { _ in
                    tableView.reloadData()
                }
                
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let item = stickerStoreItems.remove(at: sourceIndexPath.row)
        stickerStoreItems.insert(item, at: destinationIndexPath.row)
        tableView.reloadData()
    }
    
}

extension StickersEditingViewController: UITableViewDragDelegate {
    
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let item = UIDragItem(itemProvider: NSItemProvider())
        return [item]
    }
    
    func tableView(_ tableView: UITableView, dragSessionIsRestrictedToDraggingApplication session: UIDragSession) -> Bool {
        return true
    }
    
}
