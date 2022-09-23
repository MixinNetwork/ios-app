import Foundation

struct Acknowledgement: Decodable {
    
    let title: String
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case content = "FooterText"
    }
    
}

extension Acknowledgement {
    
    private struct Root: Decodable {
        
        let acknowledgements: [Acknowledgement]
        
        enum CodingKeys: String, CodingKey {
            case acknowledgements = "PreferenceSpecifiers"
        }
        
    }
    
    static func read(from url: URL) -> [Acknowledgement] {
        do {
            let data = try Data(contentsOf: url)
            let root = try PropertyListDecoder().decode(Root.self, from: data)
            return root.acknowledgements.dropFirst().dropLast()
        } catch {
            return []
        }
    }
    
}
