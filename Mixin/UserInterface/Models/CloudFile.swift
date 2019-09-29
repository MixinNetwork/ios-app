import Foundation

class CloudFile {

    private let url: URL
    private let query = NSMetadataQuery()

    private var observer: NSObjectProtocol?

    init(url: URL) {
        self.url = url
        self.query.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemPathKey, url.path)
        self.query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
    }

    deinit {
        removeObserver()
    }

    func exist() -> Bool {
        return FileManager.default.isUbiquitousItem(at: url)
    }

    func isDownloaded() -> Bool {
        return (try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus == .current) ?? false
    }

    func startDownload(progress: @escaping (Float, Bool) -> Void) throws {
        try FileManager.default.startDownloadingUbiquitousItem(at: url)

        query.valueListAttributes = [NSMetadataUbiquitousItemPercentDownloadedKey,
                                     NSMetadataUbiquitousItemDownloadingStatusKey]
        observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: nil, queue: .main) { [weak self](notification) in

            guard let metadataItem = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem])?.first else {
                return
            }

            for attrName in metadataItem.attributes {
                switch attrName {
                case NSMetadataUbiquitousItemPercentDownloadedKey:
                    guard let percent = metadataItem.value(forAttribute: attrName) as? NSNumber else {
                        return
                    }
                    progress(percent.floatValue / 100, false)
                case NSMetadataUbiquitousItemDownloadingStatusKey:
                    guard let status = metadataItem.value(forAttribute: attrName) as? String else {
                        return
                    }
                    guard status == NSMetadataUbiquitousItemDownloadingStatusDownloaded else {
                        return
                    }
                    progress(1, true)
                    self?.removeObserver()
                default:
                    break
                }
            }
        }
        query.start()
    }

    func startUpload(destination: URL, progress: @escaping (Float, Bool) -> Void) {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)


        do {
            try FileManager.default.copyItem(at: url, to: tmpFile)
            try FileManager.default.setUbiquitous(true, itemAt: url, destinationURL: destination)

            query.valueListAttributes = [NSMetadataUbiquitousItemPercentUploadedKey,
                                         NSMetadataUbiquitousItemIsUploadedKey]
            observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: nil, queue: .main) { [weak self](notification) in

                guard let metadataItem = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem])?.first else {
                    return
                }

                for attrName in metadataItem.attributes {
                    switch attrName {
                    case NSMetadataUbiquitousItemPercentUploadedKey:
                        guard let percent = metadataItem.value(forAttribute: attrName) as? NSNumber else {
                            return
                        }
                        progress(percent.floatValue / 100, false)
                    case NSMetadataUbiquitousItemIsUploadedKey:
                        guard let status = metadataItem.value(forAttribute: attrName) as? NSNumber, status.boolValue else {
                            return
                        }
                        progress(1, true)
                        self?.removeObserver()
                    default:
                        break
                    }
                }
            }
            query.start()
        } catch {
            if tmpFile.fileExists {
                try? FileManager.default.removeItem(at: tmpFile)
            }
        }
    }

    private func removeObserver() {
        guard let observer = self.observer else {
            return
        }
        query.stop()
        NotificationCenter.default.removeObserver(observer)
        self.observer = nil
    }
}
