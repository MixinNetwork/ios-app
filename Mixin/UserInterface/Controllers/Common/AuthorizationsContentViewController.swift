import UIKit
import MixinServices

class AuthorizationsContentViewController: UIViewController {
    
    let tableView = UITableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.backgroundColor = .background
        tableView.separatorStyle = .none
        tableView.register(R.nib.authorizationTableViewCell)
        tableView.rowHeight = 80
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
    }
    
}

extension AuthorizationsContentViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.authorization, for: indexPath)!
    }
    
}

extension AuthorizationsContentViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
    
}
