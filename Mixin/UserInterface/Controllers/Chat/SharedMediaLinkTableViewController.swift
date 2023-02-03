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
        dates.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items[dates[section]]?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.shared_media_link, for: indexPath)!
        cell.linkLabel.text = items[dates[indexPath.section]]?[indexPath.row].link
        return cell
    }
    
}

extension SharedMediaLinkTableViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseId) as! SharedMediaTableHeaderView
        view.label.text = dates[section]
        return view
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let item = items[dates[indexPath.section]]?[indexPath.row], let url = URL(string: item.link), let container = parent?.parent {
            let context = MixinWebViewController.Context(conversationId: conversationId, initialUrl: url)
            MixinWebViewController.presentInstance(with: context, asChildOf: container)
        }
    }
    
}

extension SharedMediaLinkTableViewController {
    
    private func reloadData() {
        guard let conversationId = self.conversationId else {
            return
        }
        DispatchQueue.global().async { [weak self] in
            var dates = [String]()
            var items = [String: [HyperlinkItem]]()
            let linkItems = HyperlinkDAO.shared.hyperlinks(conversationId: conversationId)
            for item in linkItems {
                let date = item.createdAt.toUTCDate()
                let title = DateFormatter.dateSimple.string(from: date)
                if items[title] != nil {
                    items[title]!.append(item)
                } else {
                    dates.append(title)
                    items[title] = [item]
                }
            }
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.dates = dates
                self.items = items
                self.tableView.reloadData()
                self.tableView.checkEmpty(dataCount: items.count,
                                          text: R.string.localizable.no_links(),
                                          photo: R.image.emptyIndicator.ic_shared_link()!)
            }
        }
    }
    
}
