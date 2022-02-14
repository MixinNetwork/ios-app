import Foundation
import GRDB

public protocol PersistableWork: Work {
    
    static var typeIdentifier: String { get }
    
    var context: Data? { get }
    var priority: PersistedWork.Priority { get }
    
    init(id: String, context: Data?) throws
    
    func updatePersistedContext()
    
}

extension PersistableWork {
    
    public func updatePersistedContext() {
        WorkDAO.shared.update(context: context, forWorkWith: id)
    }
    
}
