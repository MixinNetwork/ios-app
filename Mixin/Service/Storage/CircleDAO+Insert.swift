import Foundation
import MixinServices
import WCDBSwift

extension CircleDAO {
    
    func insertOrReplace(circle: CircleResponse) {
        let circle = Circle(circleId: circle.circleId, name: circle.name)
        MixinDatabase.shared.insertOrReplace(objects: [circle])
    }
    
}
