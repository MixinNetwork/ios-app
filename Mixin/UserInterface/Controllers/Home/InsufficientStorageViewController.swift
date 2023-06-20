import UIKit
import MixinServices

class InsufficientStorageViewController: UIViewController {
    
    private static let memoryThreshold = 100 * bytesPerMegaByte
    
    class var needsFreeUpStorage: Bool {
        guard let deviceFreeSpace = deviceFreeSpace(), let attachmentsSize = attachmentsSize() else {
            return false
        }
        return (deviceFreeSpace < Self.memoryThreshold) && (attachmentsSize > Self.memoryThreshold - deviceFreeSpace)
    }
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.home.insufficient_storage()!
        let navigationController = LoneBackButtonNavigationController(rootViewController: vc)
        return navigationController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func skipAction(_ sender: Any) {
        AppDelegate.current.mainWindow.rootViewController = HomeContainerViewController()
    }
    
    @IBAction func viewStorageAction(_ sender: Any) {
        let vc = StorageUsageViewController.instance(insufficientStorage: true)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private class func attachmentsSize() -> UInt? {
        let containerPath = AttachmentContainer.url.path
        guard let filePaths = FileManager.default.subpaths(atPath: containerPath) else {
            Logger.general.info(category: "InsufficientStorage", message: "Get attachment paths failed")
            return nil
        }
        let size = filePaths.reduce(0) { previousSize, path in
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: "\(containerPath)/\(path)")
                if let fileSize = attributes[FileAttributeKey.size] as? UInt64 {
                    return previousSize + Int(fileSize)
                } else {
                    return previousSize
                }
            } catch {
                Logger.general.error(category: "InsufficientStorage", message: "Error reading attributes for file at \(path): \(error)")
                return previousSize
            }
        }
        return UInt(size)
    }
    
    private class func deviceFreeSpace() -> UInt? {
        do {
            let attributesOfFileSystem = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let freeSize = (attributesOfFileSystem[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            return UInt(freeSize)
        } catch {
            Logger.general.info(category: "InsufficientStorage", message: "Get system free size failed: \(error)")
            return nil
        }
    }
    
}
