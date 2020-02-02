import UIKit
import MixinServices

class SharedMediaDataTableViewController: SharedMediaTableViewController {
    
    typealias ItemType = DataMessageViewModel
    
    override var conversationId: String! {
        didSet {
            dataSource.conversationId = conversationId
        }
    }
    
    private let dataSource = SharedMediaDataSource<ItemType, SharedMediaCategorizer<ItemType>>()
    
    private var previewDocumentController: UIDocumentInteractionController?
    private var previewDocumentMessageId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(R.nib.sharedMediaDataCell)
        tableView.dataSource = self
        tableView.delegate = self
        dataSource.setDelegate(self)
        dataSource.reload()
    }
    
    private func preview(viewModel: DataMessageViewModel) {
        guard let mediaUrl = viewModel.message.mediaUrl else {
            return
        }
        let url = AttachmentContainer.url(for: .files, filename: mediaUrl)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        previewDocumentController = UIDocumentInteractionController(url: url)
        previewDocumentController?.delegate = self
        if !(previewDocumentController?.presentPreview(animated: true) ?? false) {
            previewDocumentController?.presentOpenInMenu(from: CGRect.zero, in: self.view, animated: true)
        }
        previewDocumentMessageId = viewModel.messageId
    }
    
}

extension SharedMediaDataTableViewController: SharedMediaDataSourceDelegate {
    
    func sharedMediaDataSource(_ dataSource: AnyObject, itemsForConversationId conversationId: String, location: ItemType?, count: Int) -> [ItemType] {
        let messages = MessageDAO.shared.getDataMessages(conversationId: conversationId, earlierThan: location?.message, count: count)
        return messages.map { DataMessageViewModel(message: $0) }
    }
    
    func sharedMediaDataSource(_ dataSource: AnyObject, itemForMessageId messageId: String) -> ItemType? {
        guard let msg = MessageDAO.shared.getFullMessage(messageId: messageId) else {
            return nil
        }
        return DataMessageViewModel(message: msg)
    }
    
    func sharedMediaDataSourceDidReload(_ dataSource: AnyObject) {
        tableView.reloadData()
        tableView.checkEmpty(dataCount: self.dataSource.numberOfSections,
                             text: R.string.localizable.chat_shared_data_empty(),
                             photo: R.image.ic_shared_data()!)
    }
    
    func sharedMediaDataSource(_ dataSource: AnyObject, didUpdateItemAt indexPath: IndexPath) {
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    func sharedMediaDataSource(_ dataSource: AnyObject, didRemoveItemAt indexPath: IndexPath) {
        if self.dataSource.item(at: indexPath)?.messageId == previewDocumentMessageId {
            previewDocumentController?.dismissPreview(animated: true)
            previewDocumentController?.dismissMenu(animated: true)
            previewDocumentController = nil
            previewDocumentMessageId = nil
        }
        if self.dataSource.numberOfItems(in: indexPath.section) == 1 {
            tableView.deleteSections(IndexSet(integer: indexPath.section), with: .automatic)
        } else {
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
    
}

extension SharedMediaDataTableViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.numberOfSections
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.numberOfItems(in: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.shared_media_data, for: indexPath)!
        if let item = dataSource.item(at: indexPath) {
            cell.render(viewModel: item)
            cell.attachmentLoadingDelegate = self
        }
        return cell
    }
    
}

extension SharedMediaDataTableViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        dataSource.loadMoreEarlierItemsIfNeeded(location: indexPath)
        guard let viewModel = dataSource.item(at: indexPath), viewModel.automaticallyLoadsAttachment else {
            return
        }
        viewModel.beginAttachmentLoading(isTriggeredByUser: false)
        (cell as? AttachmentLoadingMessageCell)?.updateOperationButtonStyle()
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let viewModel = dataSource.item(at: indexPath) else {
            return
        }
        viewModel.cancelAttachmentLoading(isTriggeredByUser: false)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseId) as! SharedMediaTableHeaderView
        view.label.text = dataSource.title(of: section)
        return view
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let viewModel = dataSource.item(at: indexPath) {
            UIApplication.homeContainerViewController?.pipController?.pauseAction(self)
            preview(viewModel: viewModel)
        }
    }
    
}

extension SharedMediaDataTableViewController: AttachmentLoadingMessageCellDelegate {
    
    func attachmentLoadingCellDidSelectNetworkOperation(_ cell: UITableViewCell & AttachmentLoadingMessageCell) {
        guard let indexPath = tableView.indexPath(for: cell), let viewModel = dataSource.item(at: indexPath) else {
            return
        }
        switch viewModel.operationButtonStyle {
        case .download, .upload:
            viewModel.beginAttachmentLoading(isTriggeredByUser: true)
        case .busy:
            viewModel.cancelAttachmentLoading(isTriggeredByUser: true)
        case .expired, .finished:
            break
        }
        cell.updateOperationButtonStyle()
    }
    
}

extension SharedMediaDataTableViewController: UIDocumentInteractionControllerDelegate {
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        previewDocumentController = nil
        previewDocumentMessageId = nil
    }
    
}
