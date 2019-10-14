import Foundation

class CloudFile {

    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func isDownloaded() -> Bool {
        return (try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus == .current) ?? false
    }

    func isUploaded() -> Bool {
        return (try? url.resourceValues(forKeys: [.ubiquitousItemIsUploadedKey]).ubiquitousItemIsUploaded) ?? false
    }

    func isStoredCloud() -> Bool {
        return FileManager.default.isUbiquitousItem(at: url)
    }

    func remove() throws {
        try FileManager.default.removeItem(at: url)
    }

    func startDownload(progress: @escaping (Float) -> Void) throws {
        guard !isDownloaded() else {
            return
        }
        try FileManager.default.startDownloadingUbiquitousItem(at: url)

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        query.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemPathKey, url.path)
        query.valueListAttributes = [NSMetadataUbiquitousItemPercentDownloadedKey,
                                     NSMetadataUbiquitousItemDownloadingStatusKey]

        let semaphore = DispatchSemaphore(value: 0)
        let observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: nil, queue: .main) { (notification) in

            guard let metadataItem = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem])?.first else {
                return
            }

            for attrName in metadataItem.attributes {
                switch attrName {
                case NSMetadataUbiquitousItemPercentDownloadedKey:
                    guard let percent = metadataItem.value(forAttribute: attrName) as? NSNumber else {
                        return
                    }
                    progress(percent.floatValue / 100)
                case NSMetadataUbiquitousItemDownloadingStatusKey:
                    guard let status = metadataItem.value(forAttribute: attrName) as? String else {
                        return
                    }
                    guard status == NSMetadataUbiquitousItemDownloadingStatusDownloaded else {
                        return
                    }
                    query.stop()
                    semaphore.signal()
                default:
                    break
                }
            }
        }
        DispatchQueue.main.async {
            query.start()
        }
        semaphore.wait()
        NotificationCenter.default.removeObserver(observer)
    }

    func startUpload(destination: URL, progress: @escaping (Float) -> Void) throws {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.copyItem(at: url, to: tmpFile)
            try FileManager.default.setUbiquitous(true, itemAt: tmpFile, destinationURL: destination)
        } catch {
            if tmpFile.fileExists {
                try? FileManager.default.removeItem(at: tmpFile)
            }
            throw error
        }

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        query.predicate = NSPredicate(format: "%K LIKE[CD] %@", NSMetadataItemPathKey, destination.path)
        query.valueListAttributes = [NSMetadataUbiquitousItemPercentUploadedKey,
                                     NSMetadataUbiquitousItemIsUploadedKey]

        let semaphore = DispatchSemaphore(value: 0)
        let observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { (notification) in
            guard let metadataItem = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem])?.first else {
                return
            }

            for attrName in metadataItem.attributes {
                switch attrName {
                case NSMetadataUbiquitousItemPercentUploadedKey:
                    guard let percent = metadataItem.value(forAttribute: attrName) as? NSNumber else {
                        return
                    }
                    progress(percent.floatValue / 100)
                case NSMetadataUbiquitousItemIsUploadedKey:
                    guard let status = metadataItem.value(forAttribute: attrName) as? NSNumber, status.boolValue else {
                        return
                    }
                    query.stop()
                    semaphore.signal()
                default:
                    break
                }
            }
        }
        DispatchQueue.main.async {
            query.start()
        }
        semaphore.wait()
        NotificationCenter.default.removeObserver(observer)
    }
}
