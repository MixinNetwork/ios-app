import UIKit
import MixinServices

class SharedMediaLinkTableViewController: SharedMediaTableViewController {
        
    private var dates = [String]()
    private var items = [String: [HyperlinkItem]]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(R.nib.sharedMediaLinkCell)
        tableView.dataSource = self
        tableView.delegate = self
        reloadData()
    }
    
}

extension SharedMediaLinkTableViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        items.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items[dates[section]]?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.shared_media_link, for: indexPath)!
        if let item = item(at: indexPath) {
            cell.linkLabel.text = item.link
        }
        return cell
    }
    
}

extension SharedMediaLinkTableViewController: UITableViewDelegate {
        
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseId) as! SharedMediaTableHeaderView
        if section < dates.count {
            view.label.text = dates[section]
        }
        return view
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let item = item(at: indexPath), let url = URL(string: item.link), let container = parent?.parent {
            let context = MixinWebViewController.Context(conversationId: conversationId, initialUrl: url)
            MixinWebViewController.presentInstance(with: context, asChildOf: container)
        }
    }
    
}

extension SharedMediaLinkTableViewController {
    
    private func item(at indexPath: IndexPath) -> HyperlinkItem? {
        guard indexPath.section < dates.count else {
            return nil
        }
        let date = dates[indexPath.section]
        guard let items = self.items[date], indexPath.row >= 0, indexPath.row < items.count else {
            return nil
        }
        return items[indexPath.row]
    }
    
    private func reloadData() {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else {
                return
            }
            let linkItems = HyperlinkDAO.shared.hyperlinks(conversationId: self.conversationId)
            DispatchQueue.main.async {
                for item in linkItems {
                    let date = item.createdAt.toUTCDate()
                    let title = DateFormatter.dateSimple.string(from: date)
                    if self.items[title] != nil {
                        self.items[title]!.append(item)
                    } else {
                        self.dates.append(title)
                        self.items[title] = [item]
                    }
                }
                self.tableView.reloadData()
                self.tableView.checkEmpty(dataCount: self.items.count,
                                          text: R.string.localizable.no_links(),
                                          photo: R.image.emptyIndicator.ic_shared_link()!)
            }
        }
    }
    
}
