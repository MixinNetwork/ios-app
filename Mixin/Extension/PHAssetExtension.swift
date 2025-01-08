import Photos
import CoreServices

extension PHAsset {
    
    var uniformType: UTType? {
        let identifier = value(forKey: "uniformTypeIdentifier") as? String
        ?? PHAssetResource.assetResources(for: self).first?.uniformTypeIdentifier
        return if let identifier {
            UTType(identifier)
        } else {
            nil
        }
    }
    
    var isGif: Bool {
        mediaType == .image && PHAssetResource.assetResources(for: self).contains(where: { resource in
            if let type = UTType(resource.uniformTypeIdentifier) {
                type.conforms(to: .gif)
            } else {
                false
            }
        })
    }
    
}
