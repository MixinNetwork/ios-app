import Foundation

extension URL {
    
    var isDownloaded: Bool {
        return (try? resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus == .current) ?? false
    }
    
    var isDownloading: Bool {
        return (try? resourceValues(forKeys: [.ubiquitousItemIsDownloadingKey]).ubiquitousItemIsDownloading) ?? false
    }
    
    var isUploaded: Bool {
        return (try? resourceValues(forKeys: [.ubiquitousItemIsUploadedKey]).ubiquitousItemIsUploaded) ?? false
    }
    
    var isUploading: Bool {
        return (try? resourceValues(forKeys: [.ubiquitousItemIsUploadingKey]).ubiquitousItemIsUploading) ?? false
    }
    
}
