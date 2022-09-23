import UIKit

class AcknowledgementListViewController: SettingsTableViewController {
    
    let acknowledgements: [Acknowledgement]
    let dataSource: SettingsDataSource
    
    init() {
        var acknows: [Acknowledgement] = []
        if let url = Bundle.main.url(forResource: "Pods-Mixin-acknowledgements", withExtension: "plist") {
            let pods = Acknowledgement.read(from: url)
            acknows.append(contentsOf: pods)
        }
        if let url = Bundle.main.url(forResource: "Custom-acknowledgements", withExtension: "plist") {
            let customs = Acknowledgement.read(from: url)
            acknows.append(contentsOf: customs)
        }
        self.acknowledgements = acknows
        
        let rows = acknows.map { acknow in
            SettingsRow(title: acknow.title, accessory: .disclosure)
        }
        let dataSource = SettingsDataSource(sections: [
            SettingsSection(rows: rows)
        ])
        self.dataSource = dataSource
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
}

extension AcknowledgementListViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let acknow = acknowledgements[indexPath.row]
        let viewController = AcknowledgementViewController(acknowledgement: acknow)
        let container = ContainerViewController.instance(viewController: viewController, title: acknow.title)
        navigationController?.pushViewController(container, animated: true)
    }
    
}
