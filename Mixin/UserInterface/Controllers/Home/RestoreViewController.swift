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
        updateProgressLabel(progress: 0)
        DispatchQueue.global().async {
            guard FileManager.default.ubiquityIdentityToken != nil else {
                return
            }
            guard let backupDir = MixinFile.iCloudBackupDirectory else {
                return
            }

            MixinDatabase.shared.close()
            do {
                self.updateProgressLabel(progress: 0.01)
                try self.restoreDatabase(backupDir: backupDir)
                self.updateProgressLabel(progress: 0.3)
                try self.restorePhotosAndAudios(backupDir: backupDir)

                MixinDatabase.shared.initDatabase(clearSentSenderKey: true)
                DatabaseUserDefault.shared.initiatedFTS = false
                AccountUserDefault.shared.hasRestoreChat = false
                DispatchQueue.main.async {
                    AppDelegate.current.window?.rootViewController = makeInitialViewController()
                }
            } catch {
                #if DEBUG
                print(error)
                #endif
                DispatchQueue.main.async {
                    self.restoreButton.isBusy = false
                    self.skipButton.isHidden = false
                    self.progressLabel.isHidden = true
                }
                UIApplication.traceError(error)
            }
        }
    }

    @IBAction func skipAction(_ sender: Any) {
        AccountUserDefault.shared.hasRestoreChat = false
        AccountUserDefault.shared.hasRestoreFilesAndVideos = false
        AppDelegate.current.window?.rootViewController =
            makeInitialViewController()
    }

    private func downloadFromCloud(url: URL) throws {
        guard url.cloudExist() else {
            return
        }

        if try url.cloudDownloaded() {
            return
        }

        try FileManager.default.startDownloadingUbiquitousItem(at: url)
        repeat {
            Thread.sleep(forTimeInterval: 1)

            if stopDownload {
                return
            } else if try url.cloudDownloaded() {
                return
            } else if FileManager.default.fileExists(atPath: url.path) && FileManager.default.fileSize(url.path) > 0 {
                return
            }
        } while true
    }

    private func restoreDatabase(backupDir: URL) throws {
        let localURL = MixinFile.databaseURL
        if FileManager.default.fileExists(atPath: localURL.path) {
            try Database(withPath: localURL.path).close {
                try FileManager.default.removeItem(at: localURL)
                try self.restoreDatabase(backupDir: backupDir)
            }
            return
        }

        let cloudURL = backupDir.appendingPathComponent(MixinFile.backupDatabase.lastPathComponent)
        try downloadFromCloud(url: cloudURL)

        guard FileManager.default.fileExists(atPath: cloudURL.path) else {
            return
        }
        
        try? FileManager.default.removeItem(at: localURL)
        try FileManager.default.copyItem(at: cloudURL, to: localURL)
    }

    private func restorePhotosAndAudios(backupDir: URL) throws {
        let chatDir = MixinFile.rootDirectory.appendingPathComponent("Chat")
        let categories: [MixinFile.ChatDirectory] = [.photos, .audios]

        try FileManager.default.createDirectoryIfNeeded(dir: chatDir)
        
        var totalProgress: Float = 0.3
        for category in categories {
            let cloudURL = backupDir.appendingPathComponent("mixin.\(category.rawValue.lowercased()).zip")

            try downloadFromCloud(url: cloudURL)

            guard FileManager.default.fileExists(atPath: cloudURL.path) else {
                continue
            }

            let localZip = chatDir.appendingPathComponent("\(category.rawValue).zip")

            try? FileManager.default.removeItem(at: localZip)
            try FileManager.default.copyItem(at: cloudURL, to: localZip)

            let localDir = chatDir.appendingPathComponent(category.rawValue)

            do {
                try Zip.unzipFile(localZip, destination: localDir, overwrite: true, password: nil, progress: { (progress) in
                    self.updateProgressLabel(progress: totalProgress + Float(progress) * 0.35)
                })
            } catch {
                #if DEBUG
                print(error)
                #endif
                UIApplication.traceError(error)
            }
            try? FileManager.default.removeItem(at: localZip)
            totalProgress += 0.35
        }
    }
    
    private func updateProgressLabel(progress: Float) {
        performSynchronouslyOnMainThread {
            let number = NSNumber(value: progress)
            let percentage = NumberFormatter.simplePercentage.string(from: number)
            progressLabel.text = percentage
        }
    }
    
}
