import Foundation

public final class RefreshInscriptionJob: AsynchronousJob {
    
    private let inscriptionHash: String
    
    private var inscription: InscriptionItem?
    
    public init(inscriptionHash: String) {
        self.inscriptionHash = inscriptionHash
    }
    
    override public func getJobId() -> String {
        return "refresh-inscription-" + inscriptionHash
    }
    
    public override func execute() -> Bool {
        Task {
            do {
                let inscription = try await InscriptionAPI.inscription(inscriptionHash: inscriptionHash)
                if !MixinService.isStopProcessMessages {
                    InscriptionDAO.shared.save(inscription: inscription)
                }
                
                let collection = try await InscriptionAPI.collection(collectionHash: inscription.collectionHash)
                if !MixinService.isStopProcessMessages {
                    InscriptionDAO.shared.save(collection: collection)
                }
            } catch {
                reporter.report(error: error)
            }
            self.finishJob()
        }
        return true
    }
}
