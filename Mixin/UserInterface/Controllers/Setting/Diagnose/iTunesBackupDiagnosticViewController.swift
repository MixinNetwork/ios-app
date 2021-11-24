import UIKit
import MixinServices

class iTunesBackupDiagnosticViewController: UIViewController {
    
    @IBOutlet weak var diagnoseButton: BusyButton!
    @IBOutlet weak var outputTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        outputTextView.contentInset.left = 20
        outputTextView.contentInset.right = 20
        container?.rightButton.isEnabled = true
    }
    
    @IBAction func diagnose(_ sender: Any) {
        outputTextView.text = ""
        diagnoseButton.isBusy = true
        DispatchQueue.global().async {
            defer {
                DispatchQueue.main.async {
                    self.diagnoseButton.isBusy = false
                }
            }
            let urls = [
                AppGroupContainer.url,
                
                AppGroupContainer.documentsUrl,
                
                AppGroupContainer.signalDatabaseUrl,
                AppGroupContainer.documentsUrl.appendingPathComponent("signal.db-wal", isDirectory: false),
                AppGroupContainer.documentsUrl.appendingPathComponent("signal.db-shm", isDirectory: false),
                
                AppGroupContainer.accountUrl,
                
                AppGroupContainer.userDatabaseUrl,
                AppGroupContainer.accountUrl.appendingPathComponent("mixin.db-wal", isDirectory: false),
                AppGroupContainer.accountUrl.appendingPathComponent("mixin.db-shm", isDirectory: false),
                
                AppGroupContainer.taskDatabaseUrl,
                AppGroupContainer.accountUrl.appendingPathComponent("task.db-wal", isDirectory: false),
                AppGroupContainer.accountUrl.appendingPathComponent("task.db-shm", isDirectory: false),
                
                AttachmentContainer.url
            ]
            for url in urls {
                do {
                    let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
                    let isExcludedFromBackup = values.isExcludedFromBackup ?? true
                    if isExcludedFromBackup {
                        try (url as NSURL).setResourceValue(false, forKey: .isExcludedFromBackupKey)
                        self.output("⚠️ Fixed a non-backup URL: \(url)")
                    } else {
                        self.output("✅ Backup URL: \(url)")
                    }
                } catch {
                    self.output("❌ Failed to manipulate URL: \(url), error: \(error)")
                }
            }
            
            let enumerator = FileManager.default.enumerator(at: AttachmentContainer.url, includingPropertiesForKeys: [.isExcludedFromBackupKey]) { url, error in
                self.output("❌ Enumeration error on URL: \(url), error: \(error)")
                return true
            }
            guard let enumerator = enumerator else {
                self.output("❌ Enumerator is nil")
                return
            }
            var backupCount = 0
            var fixedURLs: [URL] = []
            var failedURLs: [(URL, Error)] = []
            while let url = enumerator.nextObject() as? URL {
                do {
                    let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
                    let isExcludedFromBackup = values.isExcludedFromBackup ?? true
                    if isExcludedFromBackup {
                        do {
                            try (url as NSURL).setResourceValue(false, forKey: .isExcludedFromBackupKey)
                            fixedURLs.append(url)
                        } catch {
                            failedURLs.append((url, error))
                        }
                    } else {
                        backupCount += 1
                    }
                } catch {
                    failedURLs.append((url, error))
                }
            }
            self.output("\nAttachment enumeration:\n✅ \(backupCount) files are OK\n")
            for url in fixedURLs {
                self.output("⚠️ Non-backup URL is fixed: \(url)")
            }
            for (url, error) in failedURLs {
                self.output("❌ Failed to manipulate URL: \(url), error: \(error)")
            }
        }
    }
    
    private func output(_ text: String) {
        DispatchQueue.main.async {
            let newLine = text + "\n"
            self.outputTextView.text.append(newLine)
        }
    }
    
}

extension iTunesBackupDiagnosticViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        UIPasteboard.general.string = outputTextView.text
        showAutoHiddenHud(style: .notification, text: R.string.localizable.toast_copied())
    }
    
    func textBarRightButton() -> String? {
        R.string.localizable.diagnose_copy_output()
    }
    
}
