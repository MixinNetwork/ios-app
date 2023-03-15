import UIKit
import MixinServices

class DatabaseRepairViewController: UIViewController {

    @IBOutlet weak var repairButton: RoundedButton!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    
    class func instance() -> DatabaseRepairViewController {
        R.storyboard.home.repair_database()!
    }
    
    @IBAction func repairAction(_ sender: Any) {
        repairButton.isHidden = true
        stackView.isHidden = false
        activityIndicator.startAnimating()
        if DatabaseFile.exists(.backup) {
            do {
                try DatabaseFile.removeIfExists(.original)
                try DatabaseFile.copy(at: .backup, to: .original)
                let lastBackupDate = AppGroupUserDefaults.User.lastDatabaseBackupDate ?? Date()
                let formattedDate = DateFormatter.dateFull.string(from: lastBackupDate)
                stackView.isHidden = true
                alert(nil, message: R.string.localizable.repair_chat_history_success(formattedDate)) { _ in
                    AppGroupUserDefaults.User.isDatabaseCorrupted = false
                }
            } catch {
                LoginManager.shared.logout(reason: "Failed to repair database")
            }
        } else {
            LoginManager.shared.logout(reason: "Failed to repair database")
        }
    }
    
}
