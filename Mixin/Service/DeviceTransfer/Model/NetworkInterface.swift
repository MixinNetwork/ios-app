import Foundation

enum NetworkInterface {
    
    static func firstEthernetHostname() -> String? {
        var interface: UnsafeMutablePointer<ifaddrs>! = nil
        guard getifaddrs(&interface) == 0, let firstInterface = interface else {
            return nil
        }
        defer {
            freeifaddrs(firstInterface)
        }
        
        // Desktop not working with IPV6, disable for now
        let internetFamilies = [AF_INET].map(sa_family_t.init)
        let hostnameCount = NI_MAXHOST
        let hostname = UnsafeMutablePointer<CChar>.allocate(capacity: Int(hostnameCount))
        defer {
            hostname.deallocate()
        }
        while interface != nil {
            defer {
                interface = interface.pointee.ifa_next
            }
            
            let address: UnsafeMutablePointer<sockaddr> = interface.pointee.ifa_addr
            guard internetFamilies.contains(address.pointee.sa_family) else {
                continue
            }
            
            let upRunningLoopback = UInt32(IFF_UP|IFF_RUNNING|IFF_LOOPBACK)
            let upRunning = UInt32(IFF_UP|IFF_RUNNING)
            guard interface.pointee.ifa_flags & upRunningLoopback == upRunning else {
                continue
            }
            
            let interfaceName = String(cString: interface.pointee.ifa_name)
            guard interfaceName == "en0" else {
                continue
            }
            
            let result = getnameinfo(address,
                                     socklen_t(address.pointee.sa_len),
                                     hostname,
                                     UInt32(hostnameCount),
                                     nil,
                                     0,
                                     NI_NUMERICHOST)
            if result == 0 {
                let name = String(cString: hostname)
                if let scopeIndex = name.firstIndex(of: "%") {
                    return String(name.prefix(upTo: scopeIndex))
                } else {
                    return name
                }
            } else {
                continue
            }
        }
        return nil
    }
    
}
