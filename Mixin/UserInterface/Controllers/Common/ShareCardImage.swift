import UIKit
import SDWebImage
import MixinServices

enum ShareCardImage {
    
    static let dimension: CGFloat = 1024
    
    @MainActor
    static func render(view: UIView, padsToSquare: Bool) -> UIImage {
        let size = view.bounds.size
        precondition(size.width > 0 && size.height > 0 && size.width.isFinite && size.height.isFinite)
        let scale = dimension / max(size.width, size.height)
        let imageSize = CGSize(
            width: max(1, (size.width * scale).rounded()),
            height: max(1, (size.height * scale).rounded())
        )
        let canvasSize = padsToSquare ? CGSize(width: dimension, height: dimension) : imageSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let cornerRadius = view.layer.cornerRadius
        view.layer.cornerRadius = 0
        defer { view.layer.cornerRadius = cornerRadius }
        return renderer.image { context in
            (R.color.background() ?? .white).setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))
            context.cgContext.translateBy(
                x: (canvasSize.width - imageSize.width) / 2,
                y: (canvasSize.height - imageSize.height) / 2
            )
            context.cgContext.scaleBy(
                x: imageSize.width / size.width,
                y: imageSize.height / size.height
            )
            context.cgContext.clip(to: CGRect(origin: .zero, size: size))
            view.drawHierarchy(
                in: CGRect(origin: .zero, size: size),
                afterScreenUpdates: true
            )
        }
    }
    
    static func upload(imageData: Data) async throws -> String {
        try Task.checkCancellation()
        let attachment = try await MessageAPI.requestAttachment()
        try Task.checkCancellation()
        guard
            let uploadURLString = attachment.uploadUrl,
            let uploadURL = URL(string: uploadURLString),
            ["https", "http"].contains(uploadURL.scheme),
            uploadURL.host != nil,
            let viewURLString = attachment.viewUrl,
            let viewURL = URL(string: viewURLString),
            ["https", "http"].contains(viewURL.scheme),
            viewURL.host != nil
        else {
            throw URLError(.badServerResponse)
        }
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("\(imageData.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("public-read", forHTTPHeaderField: "x-amz-acl")
        let (_, response) = try await URLSession.shared.upload(for: request, from: imageData)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let cacheKey = SDWebImageManager.shared.cacheKey(for: viewURL)
        await SDImageCache.shared.storeImageData(imageData, forKey: cacheKey)
        try Task.checkCancellation()
        return viewURLString
    }
    
}
