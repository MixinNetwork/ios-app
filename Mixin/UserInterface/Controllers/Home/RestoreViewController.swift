import Foundation
import UIKit
import WCDBSwift
import Zip

class RestoreViewController: UIViewController {

    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var restoreButton: RoundedButton!
    @IBOutlet weak var progressLabel: UILabel!
    
    private var stopDownload = false
    private let query = NSMetadataQuery()

    class func instance() -> UIViewController {
        return Storyboard.home.instantiateViewController(withIdentifier: "restore")
    }

    deinit {
        stopDownload = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let subtitle = NSMutableAttributedString(string: Localized.CHAT_RESTORE_SUBTITLE)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8
        paragraphStyle.alignment = .center
        let attr: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle,
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.accessoryText
        ]
        let fullRange = NSRange(location: 0, length: subtitle.length)
        subtitle.setAttributes(attr, range: fullRange)
        subtitleLabel.attributedText = subtitle
    }
    
    @IBAction func restoreAction(_ sender: Any) {
        guard !restoreButton.isBusy else {
            return
        }
        restoreButton.isBusy = true
        skipButton.isHidden = true
        progressLabel.isHidden = false
        progressLabel.text = NumberFormatter.simplePercentage.string(from: NSNumber(value: 0.01))
        DispatchQueue.global().async {
            guard FileManager.default.ubiquityIdentityToken != nil else {
                return
            }
            guard let backupDir = MixinFile.iCloudBackupDirectory else {
                return
            }
            var cloudURL = backupDir.appendingPathComponent(MixinFile.backupDatabaseName)
            if !cloudURL.isStoredCloud {
                cloudURL = backupDir.appendingPathComponent("mixin.backup.db")
            }
            guard cloudURL.isStoredCloud else {
                DispatchQueue.main.async {
                    self.skipAction(sender)
                }
                UIApplication.traceError(code: ReportErrorCode.restoreError, userInfo: ["error": "Backup file does not exist"])
                return
            }

            DatabaseUserDefault.shared.forceUpgradeDatabase = true
            MixinDatabase.shared.close()

            let localURL = MixinFile.databaseURL
            self.removeDatabase(databaseURL: localURL)
            do {
                if !cloudURL.isDownloaded {
                    try cloudURL.downloadFromCloud(progress: { (progress) in
                        self.progressLabel.text = NumberFormatter.simplePercentage.string(from: NSNumber(value: progress))
                    })
                }
                try FileManager.default.copyItem(at: cloudURL, to: localURL)

                MixinDatabase.shared.initDatabase(clearSentSenderKey: true)
                AccountUserDefault.shared.hasRestoreChat = false

                DispatchQueue.main.async {
                    AppDelegate.current.window.rootViewController = makeInitialViewController()
                }
            } catch {
                self.restoreFailed(error: error)
            }
        }
    }

    @IBAction func skipAction(_ sender: Any) {
        AccountUserDefault.shared.hasRestoreChat = false
        AccountUserDefault.shared.hasRestoreMedia = false
        AppDelegate.current.window.rootViewController =
            makeInitialViewController()
    }

    private func removeDatabase(databaseURL: URL) {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return
        }
        let semaphore = DispatchSemaphore(value: 0)
        do {
            try Database(withPath: databaseURL.path).close {
                try FileManager.default.removeItem(at: databaseURL)
                semaphore.signal()
            }
            semaphore.wait()
        } catch {
            semaphore.signal()
            restoreFailed(error: error)
        }
    }

    private func restoreFailed(error: Swift.Error) {
        DispatchQueue.main.async {
            self.restoreButton.isBusy = false
            self.skipButton.isHidden = false
            self.progressLabel.isHidden = true
        }
        UIApplication.traceError(error)
    }
}
