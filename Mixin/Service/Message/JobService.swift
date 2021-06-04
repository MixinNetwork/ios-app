import Foundation
import MixinServices

class JobService {

    static let shared = JobService()
    
    private var isFirstRestore = true

    private static var canBatchProcessMessages: Bool {
        !isAppExtension &&
        canProcessMessages &&
        !MixinService.isStopProcessMessages &&
        UIApplication.isApplicationActive
    }

    @objc func restoreJobs() {
        DispatchQueue.global().async {
            guard JobService.canBatchProcessMessages else {
                return
            }
            if JobService.shared.isFirstRestore {
                JobService.shared.isFirstRestore = false

                JobService.shared.checkConversations()
                JobService.shared.restoreUploadJobs()
            } else if AppGroupUserDefaults.User.hasRestoreUploadAttachment {
                AppGroupUserDefaults.User.hasRestoreUploadAttachment = false
                JobService.shared.restoreUploadJobs()
            }
            CallService.shared.handlePendingWebRTCJobs()
            JobService.shared.recoverMediaJobs()
        }
    }

    private func checkConversations() {
        let startConversationIds = ConversationDAO.shared.getStartStatusConversations()
        for conversationId in startConversationIds {
            ConcurrentJobQueue.shared.addJob(job: CreateConversationJob(conversationId: conversationId))
        }

        let participantIds = ParticipantDAO.shared.getSyncParticipantIds()
        if participantIds.count > 0 {
            ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: participantIds, updateParticipantStatus: true))
        }
    }
    
    func restoreUploadJobs() {
        func upload(jobId: String, messageId: String) {
            guard let message = MessageDAO.shared.getMessage(messageId: messageId) else {
                JobDAO.shared.removeJob(jobId: jobId)
                return
            }
            if message.category.hasSuffix("_IMAGE") {
                UploaderQueue.shared.addJob(job: ImageUploadJob(message: message, jobId: jobId))
            } else if message.category.hasSuffix("_DATA") {
                UploaderQueue.shared.addJob(job: FileUploadJob(message: message, jobId: jobId))
            } else if message.category.hasSuffix("_VIDEO") {
                UploaderQueue.shared.addJob(job: VideoUploadJob(message: message, jobId: jobId))
            } else if message.category.hasSuffix("_AUDIO") {
                UploaderQueue.shared.addJob(job: AudioUploadJob(message: message, jobId: jobId))
            } else if message.category == MessageCategory.SIGNAL_TRANSCRIPT.rawValue {
                let job = TranscriptAttachmentUploadJob(message: message, jobIdToRemoveAfterFinished: jobId)
                UploaderQueue.shared.addJob(job: job)
            }
        }
        
        let attachmentJobs = JobDAO.shared.nextJobs(category: .Task, action: .UPLOAD_ATTACHMENT)
        for (jobId, messageId) in attachmentJobs {
            upload(jobId: jobId, messageId: messageId)
        }
        let transcriptJobs = JobDAO.shared.nextJobs(category: .Task, action: .UPLOAD_TRANSCRIPT_ATTACHMENT)
        for (jobId, messageId) in transcriptJobs {
            upload(jobId: jobId, messageId: messageId)
        }
    }
    
    public func processDownloadJobs() {
        DispatchQueue.global().async {
            guard JobService.canBatchProcessMessages else {
                return
            }
            JobService.shared.recoverMediaJobs()
        }
    }
    
    private func recoverMediaJobs() {
        guard ReachabilityManger.shared.isReachableOnEthernetOrWiFi else {
            return
        }
        let limit = 5
        let jobs = JobDAO.shared.nextJobs(category: .Task, action: .RECOVER_ATTACHMENT, limit: limit)

        for (jobId, messageId) in jobs {
            guard let message = MessageDAO.shared.getMessage(messageId: messageId) else {
                JobDAO.shared.removeJob(jobId: jobId)
                continue
            }
            let downloadJob: AttachmentDownloadJob
            if ["_VIDEO", "_DATA", "_AUDIO", "_IMAGE"].contains(where: message.category.hasSuffix) {
                downloadJob = AttachmentDownloadJob(message: message, jobId: jobId, isRecoverAttachment: true)
            } else {
                JobDAO.shared.removeJob(jobId: jobId)
                continue
            }
            downloadJob.completionBlock = {
                guard !ConcurrentJobQueue.shared.isExistRecoverAttachment() else {
                    return
                }
                JobService.shared.processDownloadJobs()
            }
            ConcurrentJobQueue.shared.addJob(job: downloadJob)
        }
    }

}
