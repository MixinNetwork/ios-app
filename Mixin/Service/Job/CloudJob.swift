import Foundation
import MixinServices

protocol CloudJobFile {
    var srcURL: URL { get set }
    var dstURL: URL { get set }
    var size: Int64 { get set }
    var processedSize: Int64 { get set }
}

extension CloudJobFile {
    var name: String { srcURL.lastPathComponent }
    var isProcessingCompleted: Bool { processedSize >= size }
}

class CloudJob: AsynchronousJob {
    
    static let backupDidChangeNotification = Notification.Name("one.mixin.messenger.CloudJob.backupDidChange")
    
    var progress: Float {
        Float(Float64(totalProcessedSize) / Float64(totalFileSize))
    }
    
    var totalProcessedSize: Int64 {
        processedFileSize + processingFiles.values.map { $0.processedSize }.reduce(0, +)
    }
    
    var isContinueProcessing: Bool {
        !isCancelled && ReachabilityManger.shared.isReachableOnEthernetOrWiFi
    }
    
    var pendingFiles = SafeDictionary<String, CloudJobFile>()
    var processingFiles = SafeDictionary<String, CloudJobFile>()
    var totalFileSize: Int64 = 0
    var processedFileSize: Int64 = 0
    
    let query = NSMetadataQuery()
    
    class var jobId: String {
        ""
    }
    
    override func getJobId() -> String {
        Self.jobId
    }
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(queryDidUpdate(notification:)), name: .NSMetadataQueryDidUpdate, object: nil)
    }
    
    func setupQuery(backupUrl: URL) {
        query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        query.predicate = NSPredicate(format: "%K BEGINSWITH[c] %@ && kMDItemContentType != 'public.folder'", NSMetadataItemPathKey, backupUrl.path)
    }
    
    func startQuery() {
        DispatchQueue.main.async { [weak self] in
            _ = self?.query.start()
        }
    }
    
    func stopQuery() {
        DispatchQueue.main.async { [weak self] in
            self?.query.stop()
        }
    }
    
    @objc func queryDidUpdate(notification: Notification) {
        
    }
    
}
