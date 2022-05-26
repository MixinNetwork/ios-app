import Foundation
import UIKit
import MixinServices

class RestoreViewController: UIViewController {

    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var restoreButton: RoundedButton!
    @IBOutlet weak var progressLabel: UILabel!

    class func instance() -> UIViewController {
        return R.storyboard.home.restore()!    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let subtitle = NSMutableAttributedString(string: R.string.localizable.chat_restore_subtitle())
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8
        paragraphStyle.alignment = .center
        let attr: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle,
            .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
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
        Logger.general.info(category: "Restore", message: "Begin restore")
        restoreButton.isBusy = true
        skipButton.isHidden = true
        progressLabel.isHidden = false
        progressLabel.text = NumberFormatter.simplePercentage.string(from: NSNumber(value: 0.01))
        DispatchQueue.global().async {
            guard FileManager.default.ubiquityIdentityToken != nil else {
                return
            }
            guard let backupDir = backupUrl else {
                return
            }
            var cloudURL = backupDir.appendingPathComponent(backupDatabaseName)
            if !cloudURL.isStoredCloud {
                cloudURL = backupDir.appendingPathComponent("mixin.backup.db")
            }
            guard cloudURL.isStoredCloud else {
                Logger.general.info(category: "Restore", message: "Missing file: \(cloudURL.suffix(base: backupDir))")
                DispatchQueue.main.async {
                    self.skipAction(sender)
                }
                reporter.report(error: MixinError.missingBackup)
                return
            }

            let localURL = AppGroupContainer.userDatabaseUrl
            do {
                if !cloudURL.isDownloaded {
                    try self.downloadFromCloud(cloudURL: cloudURL, progress: { (progress) in
                        self.progressLabel.text = NumberFormatter.simplePercentage.string(from: NSNumber(value: progress))
                    })
                } else {
                    Logger.general.info(category: "Restore", message: "File not downloaded: \(cloudURL.suffix(base: backupDir))")
                }
                if FileManager.default.fileExists(atPath: localURL.path) {
                    UserDatabase.closeCurrent()
                    try FileManager.default.removeItem(at: localURL)
                }
                try FileManager.default.copyItem(at: cloudURL, to: localURL)

                AppGroupUserDefaults.Account.canRestoreChat = false
                AppGroupUserDefaults.Account.canRestoreMedia = true
                AppGroupUserDefaults.Database.isSentSenderKeyCleared = false
                AppGroupUserDefaults.Database.isFTSInitialized = false
                AppGroupUserDefaults.User.needsRebuildDatabase = true
                AppGroupUserDefaults.User.isCircleSynchronized = false
                
                UserDatabase.reloadCurrent()
                DispatchQueue.main.async {
                    AppDelegate.current.mainWindow.rootViewController = makeInitialViewController()
                }
            } catch {
                Logger.general.error(category: "RestoreViewController", message: "Restoration at: \(cloudURL.suffix(base: backupDir)), failed for: \(error)")
                self.restoreFailed(error: error)
            }
        }
    }

    @IBAction func skipAction(_ sender: Any) {
        Logger.general.info(category: "Restore", message: "Restoration skipped")
        AppGroupUserDefaults.Account.canRestoreChat = false
        AppGroupUserDefaults.Account.canRestoreMedia = false
        AppDelegate.current.mainWindow.rootViewController =
            makeInitialViewController()
    }
    
    private func restoreFailed(error: Swift.Error) {
        DispatchQueue.main.async {
            self.restoreButton.isBusy = false
            self.skipButton.isHidden = false
            self.progressLabel.isHidden = true
        }
        reporter.report(error: error)
    }

    private func downloadFromCloud(cloudURL: URL, progress: @escaping (Float) -> Void) throws {
        guard !cloudURL.isDownloaded else {
            progress(1)
            return
        }
        try FileManager.default.startDownloadingUbiquitousItem(at: cloudURL)

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        query.predicate = NSPredicate(format: "%K LIKE[CD] %@", NSMetadataItemPathKey, cloudURL.path)
        query.valueListAttributes = [NSMetadataUbiquitousItemPercentDownloadedKey,
                                     NSMetadataUbiquitousItemDownloadingStatusKey]

        let semaphore = DispatchSemaphore(value: 0)
        let observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: nil, queue: .main) { (notification) in
            guard let metadataItem = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem])?.first else {
                return
            }

            if let percent = metadataItem.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double, percent > 1 {
                progress(Float(percent) / 100)
            }
            if let status = metadataItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
                guard status == NSMetadataUbiquitousItemDownloadingStatusCurrent else {
                    return
                }
                query.stop()
                semaphore.signal()
            }
        }
        DispatchQueue.main.async {
            query.start()
        }
        semaphore.wait()
        NotificationCenter.default.removeObserver(observer)
    }
}
