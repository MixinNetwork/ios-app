import UIKit
import WCDBSwift

class BackupViewController: UITableViewController {
    
    @IBOutlet weak var switchIncludeFiles: UISwitch!
    @IBOutlet weak var switchIncludeVideos: UISwitch!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var backupIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var backupLabel: UILabel!
    
    private let footerReuseId = "footer"
    
    private lazy var actionSectionFooterView = TitledShadowFooterView()
    private lazy var backupAvailabilityQuery = BackupAvailabilityQuery()
    
    private var timer: Timer?
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    class func instance() -> UIViewController {
        let vc = Storyboard.setting.instantiateViewController(withIdentifier: "backup")
        return ContainerViewController.instance(viewController: vc, title: Localized.SETTING_BACKUP_TITLE)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateTableViewContentInsetBottom()
        tableView.register(TitledShadowFooterView.self, forHeaderFooterViewReuseIdentifier: footerReuseId)
        switchIncludeFiles.isOn = CommonUserDefault.shared.hasBackupFiles
        switchIncludeVideos.isOn = CommonUserDefault.shared.hasBackupVideos
        reloadActionSectionFooterLabel()
        NotificationCenter.default.addObserver(self, selector: #selector(backupChanged), name: .BackupDidChange, object: nil)
        if BackupJobQueue.shared.isBackingUp {
            backingUI()
        } else {
            backupAvailabilityQuery.fileExist() { (exist) in
                if !exist {
                    CommonUserDefault.shared.lastBackupTime = 0
                    CommonUserDefault.shared.lastBackupSize = 0
                }
            }
        }
    }
    
    override func viewSafeAreaInsetsDidChange() {
        if #available(iOS 11.0, *) {
            super.viewSafeAreaInsetsDidChange()
        }
        updateTableViewContentInsetBottom()
    }
    
    @objc func backupChanged() {
        timer?.invalidate()
        timer = nil
        reloadActionSectionFooterLabel(progress: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.reloadActionSectionFooterLabel()
            self.backupIndicatorView.stopAnimating()
            self.backupIndicatorView.isHidden = true
            self.backupLabel.text = Localized.SETTING_BACKUP_NOW
            self.switchIncludeFiles.isEnabled = true
            self.switchIncludeVideos.isEnabled = true
            self.tableView.reloadData()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        switch CommonUserDefault.shared.backupCategory {
        case .daily:
            categoryLabel.text = Localized.SETTING_BACKUP_DAILY
        case .weekly:
            categoryLabel.text = Localized.SETTING_BACKUP_WEEKLY
        case .monthly:
            categoryLabel.text = Localized.SETTING_BACKUP_MONTHLY
        case .off:
            categoryLabel.text = Localized.SETTING_BACKUP_OFF
        }
    }

    @IBAction func switchIncludeFiles(_ sender: Any) {
        CommonUserDefault.shared.hasBackupFiles = switchIncludeFiles.isOn
    }

    @IBAction func switchIncludeVideos(_ sender: Any) {
        CommonUserDefault.shared.hasBackupVideos = switchIncludeVideos.isOn
    }

    private func backingUI() {
        backupIndicatorView.startAnimating()
        backupIndicatorView.isHidden = false
        backupLabel.text = Localized.SETTING_BACKING
        switchIncludeFiles.isEnabled = false
        switchIncludeVideos.isEnabled = false
        reloadActionSectionFooterLabel()
        tableView.reloadData()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (timer) in
            self?.reloadActionSectionFooterLabel()
        })
    }
    
    private func reloadActionSectionFooterLabel(progress: Float? = nil) {
        let text: String?
        if let progress = progress ?? BackupJobQueue.shared.backupJob?.progress.fractionCompleted {
            let number = NSNumber(value: progress)
            let percentage = NumberFormatter.simplePercentage.string(from: number)
            text = Localized.SETTING_BACKUP_PROGRESS(progress: percentage ?? "")
        } else {
            let time = CommonUserDefault.shared.lastBackupTime
            if let size = CommonUserDefault.shared.lastBackupSize, size > 0, time > 0 {
                text = Localized.SETTING_BACKUP_LAST(time: DateFormatter.backupFormatter.string(from: Date(timeIntervalSince1970: time)), size: size.sizeRepresentation())
            } else {
                text = nil
            }
        }
        actionSectionFooterView.label.text = text
    }
    
    private func updateTableViewContentInsetBottom() {
        if view.compatibleSafeAreaInsets.bottom < 10 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
}

extension BackupViewController {

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 && indexPath.row == 0 {
            guard !BackupJobQueue.shared.isBackingUp else {
                return
            }
            if BackupJobQueue.shared.addJob(job: BackupJob(immediatelyBackup: true)) {
                backingUI()
            }
        } else if indexPath.section == 1 && indexPath.row == 0 {
            navigationController?.pushViewController(BackupCategoryViewController.instance(), animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 0 {
            return actionSectionFooterView
        } else {
            let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! TitledShadowFooterView
            view.label.text = Localized.SETTING_BACKUP_AUTO_TIPS
            return view
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
    
}
