import UIKit

final class SendingDestinationSelectorViewController: PopupSelectorViewController {
    
    enum Destination: Int {
        case contact = 0
        case address = 1
    }
    
    let destinations: [Destination]
    let onSelected: (Destination) -> Void
    
    init(destinations: [Destination], onSelected: @escaping (Destination) -> Void) {
        self.destinations = destinations
        self.onSelected = onSelected
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = 74
        tableView.register(R.nib.sendingDestinationCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 35, right: 0)
        titleView.titleLabel.text = R.string.localizable.send()
    }
    
}

extension SendingDestinationSelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        destinations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.sending_destination, for: indexPath)!
        let destination = Destination(rawValue: indexPath.row)!
        switch destination {
        case .contact:
            cell.iconImageView.image = R.image.wallet.send_destination_contact()
            cell.titleLabel.text = R.string.localizable.send_to_contact()
            cell.freeLabel.isHidden = false
            cell.subtitleLabel.text = R.string.localizable.send_to_contact_description()
        case .address:
            cell.iconImageView.image = R.image.wallet.send_destination_address()
            cell.titleLabel.text = R.string.localizable.send_to_address()
            cell.freeLabel.isHidden = true
            cell.subtitleLabel.text = R.string.localizable.send_to_address_description()
        }
        return cell
    }
    
}

extension SendingDestinationSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presentingViewController?.dismiss(animated: true, completion: { [onSelected] in
            let destination = Destination(rawValue: indexPath.row)!
            onSelected(destination)
        })
    }
    
}
