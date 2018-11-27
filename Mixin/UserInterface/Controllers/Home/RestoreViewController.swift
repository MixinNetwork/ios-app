import Foundation
import UIKit
import Bugsnag
import WCDBSwift
import Zip

class RestoreViewController: UIViewController {

    @IBOutlet weak var restoreButton: StateResponsiveButton!
    @IBOutlet weak var skipButton: UIButton!


    class func instance() -> UIViewController {
        return Storyboard.home.instantiateViewController(withIdentifier: "restore")
    }

    @IBAction func restoreAction(_ sender: Any) {
        guard !restoreButton.isBusy else {
            return
        }
        restoreButton.isBusy = true
        DispatchQueue.global().async {
            guard FileManager.default.ubiquityIdentityToken != nil else {
                return
            }
            guard let backupDir = MixinFile.iCloudBackupDirectory else {
                return
            }

            do {
                try self.restoreDatabase(backupDir: backupDir)
                try self.restorePhotosAndAudios(backupDir: backupDir)
                AccountUserDefault.shared.hasRestoreChat = false
                DispatchQueue.main.async {
                    MixinDatabase.shared.configure(reset: true)
                    AppDelegate.current.window?.rootViewController = makeInitialViewController()
                }
            } catch {
                #if DEBUG
                print(error)
                #endif
                DispatchQueue.main.async {
                    self.restoreButton.isBusy = false
                }
                Bugsnag.notifyError(error)
            }
        }
    }

    @IBAction func skipAction(_ sender: Any) {
        AccountUserDefault.shared.hasRestoreChat = false
        AccountUserDefault.shared.hasRestoreFilesAndVideos = false
        AppDelegate.current.window?.rootViewController =
            makeInitialViewController()
    }

    private func restoreDatabase(backupDir: URL) throws {
        guard !FileManager.default.fileExists(atPath: MixinFile.databasePath) else {
            try Database(withPath: MixinFile.databasePath).close {
                try FileManager.default.removeItem(atPath: MixinFile.databasePath)
                try self.restoreDatabase(backupDir: backupDir)
            }
            return
        }

        let iCloudPath = backupDir.appendingPathComponent(MixinFile.backupDatabase.lastPathComponent)
        guard FileManager.default.fileExists(atPath: iCloudPath.path) else {
            return
        }
        
        try? FileManager.default.removeItem(atPath: MixinFile.databasePath)

        try FileManager.default.copyItem(at: iCloudPath, to: URL(fileURLWithPath: MixinFile.databasePath))
    }

    private func restorePhotosAndAudios(backupDir: URL) throws {
        let chatDir = MixinFile.rootDirectory.appendingPathComponent("Chat")
        let categories: [MixinFile.ChatDirectory] = [.photos, .audios]

        try FileManager.default.createDirectoryIfNeeded(dir: chatDir)

        let contents = try FileManager.default.contentsOfDirectory(atPath: backupDir.path)
        print(contents)

        for category in categories {
            let zip = backupDir.appendingPathComponent("mixin.\(category.rawValue.lowercased()).zip")
            guard FileManager.default.fileExists(atPath: zip.path) else {
                continue
            }

            let localZip = chatDir.appendingPathComponent("\(category.rawValue).zip")

            try? FileManager.default.removeItem(at: localZip)
            try FileManager.default.copyItem(at: zip, to: localZip)

            let localDir = chatDir.appendingPathComponent(category.rawValue)

            do {
                try Zip.unzipFile(localZip, destination: localDir, overwrite: true, password: nil)
            } catch {
                #if DEBUG
                print(error)
                #endif
                Bugsnag.notifyError(error)
            }
            try? FileManager.default.removeItem(at: localZip)
        }
    }
}
