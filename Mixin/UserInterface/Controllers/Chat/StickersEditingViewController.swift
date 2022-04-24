import UIKit
import MixinServices

class StickersEditingViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    private var albumItems = [AlbumItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.isEditing = true
        StickerStore.loadAddedAlbums { albumItems in
            DispatchQueue.main.async {
                self.albumItems = albumItems
                self.reloadData()
            }
        }
    }
    
    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    private func reloadData() {
        tableView.reloadData()
        tableView.checkEmpty(dataCount: albumItems.count,
                             text: R.string.localizable.no_STICKERS(),
                             photo: R.image.ic_sticker_smile()!)
    }
    
}

extension StickersEditingViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return albumItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.stickers_editing, for: indexPath)!
        if indexPath.row < albumItems.count {
            let albumItem = albumItems[indexPath.row]
            cell.albumItem = albumItem
            cell.onDelete = { [weak self] in
                guard let self = self else {
                    return
                }
                tableView.performBatchUpdates {
                    StickerStore.remove(item: albumItem)
                    self.albumItems.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                } completion: { _ in
                    self.reloadData()
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
        guard sourceIndexPath.row < albumItems.count && destinationIndexPath.row < albumItems.count else {
            return
        }
        let moved = albumItems.remove(at: sourceIndexPath.row)
        albumItems.insert(moved, at: destinationIndexPath.row)
        let albumIds = albumItems.map { $0.album.albumId }
        StickerStore.updateAlbumsOrder(albumIds: albumIds)
        tableView.reloadData()
    }
    
}
