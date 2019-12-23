import Foundation
import UIKit
import WCDBSwift
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
        let subtitle = NSMutableAttributedString(string: Localized.CHAT_RESTORE_SUBTITLE)
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
                DispatchQueue.main.async {
                    self.skipAction(sender)
                }
                Reporter.report(error: MixinError.missingBackup)
                return
            }

            let localURL = AppGroupContainer.mixinDatabaseUrl
            self.removeDatabase(databaseURL: localURL)
            do {
                if !cloudURL.isDownloaded {
                    try self.downloadFromCloud(cloudURL: cloudURL, progress: { (progress) in
                        self.progressLabel.text = NumberFormatter.simplePercentage.string(from: NSNumber(value: progress))
                    })
                }
                try FileManager.default.copyItem(at: cloudURL, to: localURL)

                AppGroupUserDefaults.Account.canRestoreChat = false
                AppGroupUserDefaults.Account.canRestoreMedia = true
                AppGroupUserDefaults.Database.isSentSenderKeyCleared = false
                AppGroupUserDefaults.User.needsRebuildDatabase = true
                
                DispatchQueue.main.async {
                    AppDelegate.current.window.rootViewController = makeInitialViewController()
                }
            } catch {
                self.restoreFailed(error: error)
            }
        }
    }

    @IBAction func skipAction(_ sender: Any) {
        AppGroupUserDefaults.Account.canRestoreChat = false
        AppGroupUserDefaults.Account.canRestoreMedia = false
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
        Reporter.report(error: error)
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
