import UIKit
import MixinServices

final class InscriptionViewController: UIViewController {
    
    private let backgroundView = UIVisualEffectView(effect: .darkBlur)
    private let tableView = UITableView()
    private let message: MessageItem
    
    init(message: MessageItem) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(backgroundView)
        backgroundView.snp.makeEdgesEqualToSuperview()
        backgroundView.contentView.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.backgroundColor = .clear
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 61
        tableView.separatorStyle = .none
        tableView.register(R.nib.inscriptionContentCell)
        tableView.dataSource = self
        tableView.delegate = self
    }
    
}

extension InscriptionViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inscription_content, for: indexPath)!
        return cell
    }
    
}

extension InscriptionViewController: UITableViewDelegate {
    
    
}
