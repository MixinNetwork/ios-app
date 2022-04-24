import UIKit
import MixinServices

class AttachmentDiagnosticViewController: UIViewController {
    
    @IBOutlet weak var textView: UITextView!
    
    private var isSearching = true
    private var urls: [URL] = []
    
    private var rightButtonTitle: String? {
        if isSearching || urls.isEmpty {
            return nil
        } else {
            return R.string.localizable.delete() + "(\(urls.count))"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.global().async { [weak self] in
            func append(_ url: URL) -> Bool {
                if let self = self {
                    self.urls.append(url)
                    self.textView.text.append(url.absoluteString + "\n")
                    return true
                } else {
                    return false
                }
            }
            
            let categories: [AttachmentContainer.Category] = [.photos, .audios, .files, .videos]
            
            for category in categories {
                let path = AttachmentContainer.url(for: category, filename: nil).path
                guard let onDiskFilenames = try? FileManager.default.contentsOfDirectory(atPath: path), onDiskFilenames.count > 0 else {
                    continue
                }
                
                if category == .videos {
                    let referencedFilenames = MessageDAO.shared
                        .getMediaUrls(categories: category.messageCategory)
                        .map({ NSString(string: $0).deletingPathExtension })
                    for onDiskFilename in onDiskFilenames where !referencedFilenames.contains(where: { onDiskFilename.contains($0) }) {
                        let url = AttachmentContainer.url(for: .videos, filename: onDiskFilename)
                        let continueSearching: Bool = DispatchQueue.main.sync {
                            append(url)
                        }
                        if !continueSearching {
                            return
                        }
                    }
                } else {
                    let referencedFilenames = Set(MessageDAO.shared.getMediaUrls(categories: category.messageCategory))
                    for onDiskFilename in onDiskFilenames where !referencedFilenames.contains(onDiskFilename) {
                        let url = AttachmentContainer.url(for: category, filename: onDiskFilename)
                        let continueSearching: Bool = DispatchQueue.main.sync {
                            append(url)
                        }
                        if !continueSearching {
                            return
                        }
                    }
                }
                if self == nil {
                    return
                }
            }
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.isSearching = false
                self.container?.rightButton.setTitle(self.rightButtonTitle, for: .normal)
                self.textView.text.append("Searching finished. \(self.urls.count) items found.\n")
            }
        }
    }
    
}

extension AttachmentDiagnosticViewController: ContainerViewControllerDelegate {
    
    func textBarRightButton() -> String? {
        rightButtonTitle
    }
    
    func barRightButtonTappedAction() {
        guard !isSearching && !urls.isEmpty else {
            return
        }
        let count = urls.count
        try? urls.forEach(FileManager.default.removeItem(at:))
        urls = []
        textView.text.append("\(count) files removed\n")
        container?.rightButton.setTitle(rightButtonTitle, for: .normal)
    }
    
}
