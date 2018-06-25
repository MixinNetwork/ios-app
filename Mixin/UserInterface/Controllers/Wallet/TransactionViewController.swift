import UIKit

class TransactionViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private var asset: AssetItem!
    private var snapshot: SnapshotItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        prepareTableView()
    }

    private func prepareTableView() {
        tableView.register(UINib(nibName: "TransactionCell", bundle: nil), forCellReuseIdentifier: TransactionCell.cellIdentifier)
        tableView.register(UINib(nibName: "TransactionHeaderCell", bundle: nil), forCellReuseIdentifier: TransactionHeaderCell.cellIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = 69
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.tableFooterView = UIView()
        tableView.reloadData()
    }

    class func instance(asset: AssetItem, snapshot: SnapshotItem) -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "transaction") as! TransactionViewController
        vc.asset = asset
        vc.snapshot = snapshot
        let container = ContainerViewController.instance(viewController: vc, title: Localized.TRANSACTION_TITLE)
        container.automaticallyAdjustsScrollViewInsets = false
        return container
    }

}

extension TransactionViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : 7
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: TransactionHeaderCell.cellIdentifier) as! TransactionHeaderCell
            cell.render(asset: asset, snapshot: snapshot)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: TransactionCell.cellIdentifier) as! TransactionCell
            switch indexPath.row {
            case 0:
                cell.render(title: Localized.TRANSACTION_ID, value: snapshot.snapshotId)
            case 1:
                switch snapshot.type {
                case SnapshotType.deposit.rawValue:
                    cell.render(title: Localized.TRANSACTION_TYPE, value: Localized.TRANSACTION_TYPE_DEPOSIT)
                case SnapshotType.transfer.rawValue:
                    cell.render(title: Localized.TRANSACTION_TYPE, value: Localized.TRANSACTION_TYPE_TRANSFER)
                case SnapshotType.withdrawal.rawValue:
                    cell.render(title: Localized.TRANSACTION_TYPE, value: Localized.TRANSACTION_TYPE_WITHDRAWAL)
                case SnapshotType.fee.rawValue:
                    cell.render(title: Localized.TRANSACTION_TYPE, value: Localized.TRANSACTION_TYPE_FEE)
                case SnapshotType.rebate.rawValue:
                    cell.render(title: Localized.TRANSACTION_TYPE, value: Localized.TRANSACTION_TYPE_REBATE)
                default:
                    break
                }
            case 2:
                cell.render(title: Localized.TRANSACTION_ASSET, value: asset.name)
            case 3:
                switch snapshot.type {
                case SnapshotType.deposit.rawValue:
                    cell.render(title: Localized.TRANSACTION_SENDER, value: snapshot.sender ?? "")
                case SnapshotType.transfer.rawValue:
                    if snapshot.amount.toDouble() > 0 {
                        cell.render(title: Localized.WALLET_SNAPSHOT_FROM(fullName: ""), value: snapshot.opponentUserFullName ?? "")
                    } else {
                        cell.render(title: Localized.WALLET_SNAPSHOT_FROM(fullName: ""), value: AccountAPI.shared.account?.full_name ?? "")
                    }
                case SnapshotType.withdrawal.rawValue, SnapshotType.fee.rawValue, SnapshotType.rebate.rawValue:
                    cell.render(title: Localized.TRANSACTION_TRANSACTION_HASH, value: snapshot.transactionHash ?? "")
                default:
                    break
                }
            case 4:
                switch snapshot.type {
                case SnapshotType.deposit.rawValue:
                    cell.render(title: Localized.TRANSACTION_TRANSACTION_HASH, value: snapshot.transactionHash ?? "")
                case SnapshotType.transfer.rawValue:
                    if snapshot.amount.toDouble() > 0 {
                        cell.render(title: Localized.WALLET_SNAPSHOT_TO(fullName: ""), value: AccountAPI.shared.account?.full_name ?? "")
                    } else {
                        cell.render(title: Localized.WALLET_SNAPSHOT_TO(fullName: ""), value: snapshot.opponentUserFullName ?? "")
                    }
                case SnapshotType.withdrawal.rawValue, SnapshotType.fee.rawValue, SnapshotType.rebate.rawValue:
                    cell.render(title: Localized.TRANSACTION_RECEIVER, value: snapshot.receiver ?? "")
                default:
                    break
                }
            case 5:
                cell.render(title: Localized.TRANSACTION_MEMO, value: snapshot.memo ?? "      ")
            case 6:
                cell.render(title: Localized.TRANSACTION_DATE, value: DateFormatter.dateFull.string(from: snapshot.createdAt.toUTCDate()))
            default:
                break
            }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.section == 1, snapshot.type == SnapshotType.transfer.rawValue else {
            return
        }

        var transferUserId: String?
        if indexPath.row == 3  && snapshot.amount.toDouble() > 0 {
            transferUserId = snapshot.opponentId
        } else if indexPath.row == 4 && snapshot.amount.toDouble() < 0 {
            transferUserId = snapshot.opponentId
        }

        guard let userId = transferUserId, !userId.isEmpty else {
            return
        }

        DispatchQueue.global().async {
            guard let user = UserDAO.shared.getUser(userId: userId) else {
                return
            }
            DispatchQueue.main.async {
                UserWindow.instance().updateUser(user: user).presentView()
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? CGFloat.leastNormalMagnitude : 10
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return section == 0 ? 10 : 30
    }
    
    func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        return canCopyAction(indexPath: indexPath).0
    }
    
    func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return canCopyAction(indexPath: indexPath).0 && action == #selector(copy(_:))
    }
    
    func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        let copy: (can: Bool, body: String) = canCopyAction(indexPath: indexPath)
        guard copy.can else {
            return
        }
        UIPasteboard.general.string = copy.body
        NotificationCenter.default.post(name: .ToastMessageDidAppear, object: Localized.TOAST_COPIED)
    }

    private func canCopyAction(indexPath: IndexPath) -> (Bool, String) {
        guard indexPath.section == 1 else {
            return (false, "")
        }
        switch indexPath.row {
        case 0:
            return (true, snapshot.snapshotId)
        case 3:
            switch snapshot.type {
            case SnapshotType.deposit.rawValue:
                return (true, snapshot.sender ?? "")
            case SnapshotType.withdrawal.rawValue, SnapshotType.fee.rawValue, SnapshotType.rebate.rawValue:
                return (true, snapshot.transactionHash ?? "")
            default:
                break
            }
        case 4:
            switch snapshot.type {
            case SnapshotType.deposit.rawValue:
                return (true, snapshot.transactionHash ?? "")
            case SnapshotType.withdrawal.rawValue, SnapshotType.fee.rawValue, SnapshotType.rebate.rawValue:
                return (true, snapshot.receiver ?? "")
            default:
                break
            }
        default:
            break
        }
        return (false, "")
    }
}
