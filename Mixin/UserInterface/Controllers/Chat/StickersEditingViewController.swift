import UIKit
import MixinServices

class StickersEditingViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var stickerEmptyImageView: UIImageView!
    @IBOutlet weak var stickerEmptyWrapperView: UIView!
    
    @IBOutlet weak var stickerEmptyWrapperViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var stickerEmptyWrapperViewHeightConstraint: NSLayoutConstraint!
    
    private var stickerInfos = [StickerStore.StickerInfo]()
    private var lastViewHeight: CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateEmptyViewLayout()
        StickerStore.loadMyStickers { stickerInfos in
            DispatchQueue.main.async {
                if stickerInfos.isEmpty {
                    self.stickerEmptyWrapperView.isHidden = false
                    self.tableView.isHidden = true
                } else {
                    self.stickerInfos = stickerInfos
                    self.stickerEmptyWrapperView.isHidden = true
                    self.tableView.isHidden = false
                    self.tableView.isEditing = true
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if view.bounds.height != lastViewHeight {
            updateEmptyViewLayout()
        }
    }
    
    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    private func updateEmptyViewLayout() {
        stickerEmptyWrapperViewTopConstraint.constant = round((view.bounds.height - stickerEmptyWrapperViewHeightConstraint.constant) / 7 * 3)
    }
    
}

extension StickersEditingViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stickerInfos.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.stickers_editing, for: indexPath)!
        if indexPath.row < stickerInfos.count {
            let stickerInfo = stickerInfos[indexPath.row]
            cell.stickerInfo = stickerInfo
            cell.onDelete = { [weak self] in
                guard let self = self else {
                    return
                }
                tableView.performBatchUpdates {
                    StickerStore.remove(stickers: stickerInfo)
                    self.stickerInfos.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                } completion: { _ in
                    if self.stickerInfos.isEmpty {
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
        guard sourceIndexPath.row < stickerInfos.count && destinationIndexPath.row < stickerInfos.count else {
            return
        }
        let stickerInfo = stickerInfos.remove(at: sourceIndexPath.row)
        stickerInfos.insert(stickerInfo, at: destinationIndexPath.row)
        AppGroupUserDefaults.User.favoriteAlbums = stickerInfos.map({ $0.album.albumId })
        tableView.reloadData()
    }
    
}
