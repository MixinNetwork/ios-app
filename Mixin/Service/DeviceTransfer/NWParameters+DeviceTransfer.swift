import Foundation
import Network

extension NWParameters {
    
    static let deviceTransfer = {
        let parameters: NWParameters = .tcp
        parameters.requiredInterfaceType = .wifi
        parameters.acceptLocalOnly = true
        parameters.allowLocalEndpointReuse = true
        let deviceTransfer = NWProtocolFramer.Options(definition: DeviceTransferProtocol.definition)
        parameters.defaultProtocolStack.applicationProtocols.insert(deviceTransfer, at: 0)
        return parameters
    }()
    
}
