import UIKit
import MixinServices

class StickersEditingViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var stickerEmptyImageView: UIImageView!
    @IBOutlet weak var stickerEmptyWrapperView: UIView!
    @IBOutlet weak var stickerEmptyWrapperViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var stickerEmptyWrapperViewHeightConstraint: NSLayoutConstraint!
    
    private var stickerStoreItems = [StickerStoreItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        stickerEmptyImageView.tintColor = UIColor(displayP3RgbValue: 0xC0C5D4, alpha: 0.3)
        stickerEmptyWrapperViewTopConstraint.constant = (UIScreen.main.bounds.height - stickerEmptyWrapperViewHeightConstraint.constant) / 7 * 3
        StickersStoreManager.shared().loadMyStickers { items in
            DispatchQueue.main.async {
                if items.isEmpty {
                    self.stickerEmptyWrapperView.isHidden = false
                    self.tableView.isHidden = true
                } else {
                    self.stickerStoreItems = items
                    self.stickerEmptyWrapperView.isHidden = true
                    self.tableView.isHidden = false
                    self.tableView.isEditing = true
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
}

extension StickersEditingViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stickerStoreItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.stickers_editing, for: indexPath)!
        if indexPath.row < stickerStoreItems.count {
            cell.stickerStoreItem = stickerStoreItems[indexPath.row]
            cell.onDeleteSticker = { [weak self] in
                guard let self = self else {
                    return
                }
                tableView.performBatchUpdates {
                    StickersStoreManager.shared().remove(album: self.stickerStoreItems[indexPath.row].album)
                    self.stickerStoreItems.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                } completion: { _ in
                    if self.stickerStoreItems.isEmpty {
                        self.stickerEmptyWrapperView.isHidden = false
                        tableView.isHidden = true
                    } else {
                        tableView.reloadData()
                    }
                }
            }
        }
        return cell
    }
    
}

extension StickersEditingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
    
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath.row < stickerStoreItems.count && destinationIndexPath.row < stickerStoreItems.count else {
            return
        }
        let item = stickerStoreItems.remove(at: sourceIndexPath.row)
        stickerStoreItems.insert(item, at: destinationIndexPath.row)
        StickersStoreManager.shared().updateStickerAlbumsSequence(albumIds: stickerStoreItems.map({ $0.album.albumId }))
        tableView.reloadData()
    }
    
}
