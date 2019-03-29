import Foundation

class AssetUploadJobGroup {
    
    static func cancelJobs(on queue: JobQueue, for message: MessageItem) {
        
        func cancelOperationAndDependencies(_ operation: Operation) {
            operation.cancel()
            for dependency in operation.dependencies {
                cancelOperationAndDependencies(dependency)
            }
        }
        
        let messageId = message.messageId
        let uploadJobId: String
        if message.category.hasSuffix("_IMAGE") {
            uploadJobId = AttachmentUploadJob.jobId(messageId: messageId)
        } else if message.category.hasSuffix("_VIDEO") {
            uploadJobId = VideoUploadJob.jobId(messageId: messageId)
        } else {
            return
        }
        if let uploadJob = queue.findJobById(jodId: uploadJobId) {
            cancelOperationAndDependencies(uploadJob)
        }
    }
    
    static func jobs(message: Message) -> [BaseJob]? {
        if message.category.hasSuffix("_IMAGE") {
            if message.mediaUrl != nil {
                let uploadJob = AttachmentUploadJob(message: message)
                return [uploadJob]
            } else if message.mediaLocalIdentifier != nil {
                let assetRequestJob = ImageAssetRequestJob(message: message)
                let uploadJob = AttachmentUploadJob(message: message)
                assetRequestJob.completionBlock = { [weak assetRequestJob, weak uploadJob] in
                    uploadJob?.message = assetRequestJob?.message
                }
                uploadJob.addDependency(assetRequestJob)
                return [assetRequestJob, uploadJob]
            } else {
                return nil
            }
        } else if message.category.hasSuffix("_VIDEO") {
            if message.mediaUrl != nil {
                let uploadJob = VideoUploadJob(message: message)
                return [uploadJob]
            } else if message.mediaLocalIdentifier != nil {
                let assetRequestJob = VideoAssetRequestJob(message: message)
                let transcodeJob = VideoTranscodeJob(message: message)
                let uploadJob = VideoUploadJob(message: message)
                assetRequestJob.completionBlock = { [weak assetRequestJob, weak transcodeJob] in
                    transcodeJob?.inputAsset = assetRequestJob?.avAsset
                }
                transcodeJob.completionBlock = {  [weak transcodeJob, weak uploadJob] in
                    uploadJob?.message = transcodeJob?.message
                }
                transcodeJob.addDependency(assetRequestJob)
                uploadJob.addDependency(transcodeJob)
                return [assetRequestJob, transcodeJob, uploadJob]
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
}
