import Photos
import CoreServices

extension PHAsset {

    var uniformTypeIdentifier: CFString? {
        if let id = value(forKey: "uniformTypeIdentifier") as? String {
            return id as CFString
        } else if let res = PHAssetResource.assetResources(for: self).first {
            return res.uniformTypeIdentifier as CFString
        } else {
            return nil
        }
    }

    var pathExtension: String? {
        guard let uti = uniformTypeIdentifier, let ext = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension)?.takeRetainedValue() else {
            return nil
        }
        return String(ext)
    }

    var isGif: Bool {
        return mediaType == .image && PHAssetResource.assetResources(for: self).contains(where: { UTTypeConformsTo($0.uniformTypeIdentifier as CFString, kUTTypeGIF) })
    }
}
