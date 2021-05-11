import UIKit
import MixinServices

class SharedMediaPostTableViewController: SharedMediaTableViewController {
    
    typealias ItemType = PostMessageViewModel
    
    override var conversationId: String! {
        didSet {
            dataSource.conversationId = conversationId
        }
    }
    
    private let dataSource = SharedMediaDataSource<ItemType, SharedMediaCategorizer<ItemType>>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
        tableView.register(R.nib.sharedMediaPostCell)
        tableView.dataSource = self
        tableView.delegate = self
        dataSource.setDelegate(self)
        dataSource.reload()
    }
    
}

extension SharedMediaPostTableViewController: SharedMediaDataSourceDelegate {
    
    func sharedMediaDataSource(_ dataSource: AnyObject, itemsForConversationId conversationId: String, location: ItemType?, count: Int) -> [ItemType] {
        let messages = MessageDAO.shared.getMessages(conversationId: conversationId,
                                                     categoryIn: [.SIGNAL_POST, .PLAIN_POST],
                                                     earlierThan: location?.message,
                                                     count: count)
        let items = messages.map { PostMessageViewModel(message: $0) }
        let layoutWidth = Queue.main.autoSync {
            tableView.bounds.width
                - SharedMediaPostCell.backgroundHorizontalMargin * 2
                - SharedMediaPostCell.labelHorizontalMargin * 2
        }
        for item in items {
            item.layout(width: layoutWidth, style: [])
        }
        return items
    }
    
    func sharedMediaDataSource(_ dataSource: AnyObject, itemForMessageId messageId: String) -> ItemType? {
        guard let msg = MessageDAO.shared.getFullMessage(messageId: messageId) else {
            return nil
        }
        return PostMessageViewModel(message: msg)
    }
    
    func sharedMediaDataSourceDidReload(_ dataSource: AnyObject) {
        tableView.reloadData()
        tableView.checkEmpty(dataCount: self.dataSource.numberOfSections,
                             text: R.string.localizable.chat_shared_post_empty(),
                             photo: R.image.emptyIndicator.ic_data()!)
    }
    
    func sharedMediaDataSource(_ dataSource: AnyObject, didUpdateItemAt indexPath: IndexPath) {
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    func sharedMediaDataSource(_ dataSource: AnyObject, didRemoveItemAt indexPath: IndexPath) {
        if self.dataSource.numberOfItems(in: indexPath.section) == 1 {
            tableView.deleteSections(IndexSet(integer: indexPath.section), with: .automatic)
        } else {
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
    
}

extension SharedMediaPostTableViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        dataSource.numberOfSections
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        dataSource.numberOfItems(in: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.shared_media_post, for: indexPath)!
        if let item = dataSource.item(at: indexPath) {
            cell.render(viewModel: item)
        }
        return cell
    }
    
}

extension SharedMediaPostTableViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        dataSource.loadMoreEarlierItemsIfNeeded(location: indexPath)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseId) as! SharedMediaTableHeaderView
        view.label.text = dataSource.title(of: section)
        return view
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let container = parent?.parent, let viewModel = dataSource.item(at: indexPath) {
            let message = Message.createMessage(message: viewModel.message)
            PostWebViewController.presentInstance(message: message, asChildOf: container)
        }
    }
    
}
