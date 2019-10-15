import Foundation

extension URL {
    
    static let blank = URL(string: "about:blank")!
    static let terms = URL(string: "https://mixin.one/pages/terms")!
    static let privacy = URL(string: "https://mixin.one/pages/privacy")!
    static let aboutEncryption = URL(string: "https://mixin.one/pages/1000007")!
    static let emergencyContact = URL(string: "https://mixinmessenger.zendesk.com/hc/articles/360029154692")!
    
    func getKeyVals() -> Dictionary<String, String>? {
        var results = [String: String]()
        if let components = URLComponents(url: self, resolvingAgainstBaseURL: true), let queryItems = components.queryItems {
            for item in queryItems {
                results.updateValue(item.value ?? "", forKey: item.name)
            }
        }
        return results
    }

    var fileExists: Bool {
        return (try? checkResourceIsReachable()) ?? false
    }
    
    var fileSize: Int64 {
        return (try? resourceValues(forKeys: [.fileSizeKey]))?.allValues[.fileSizeKey] as? Int64 ?? -1
    }

    static func createTempUrl(fileExtension: String) -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString.lowercased()).\(fileExtension)")
    }
}

extension URL {

    var isDownloaded: Bool {
        return (try? resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus == .current) ?? false
    }

    var isUploaded: Bool {
        return (try? resourceValues(forKeys: [.ubiquitousItemIsUploadedKey]).ubiquitousItemIsUploaded) ?? false
    }

    var isStoredCloud: Bool {
        return FileManager.default.isUbiquitousItem(at: self)
    }

    func downloadFromCloud(progress: @escaping (Float) -> Void) throws {
        guard !isDownloaded else {
            progress(1)
            return
        }
        try FileManager.default.startDownloadingUbiquitousItem(at: self)

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        query.predicate = NSPredicate(format: "%K LIKE[CD] %@", NSMetadataItemPathKey, path)
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
                guard status == NSMetadataUbiquitousItemDownloadingStatusDownloaded || status == NSMetadataUbiquitousItemDownloadingStatusCurrent else {
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
