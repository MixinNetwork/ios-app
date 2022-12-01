import Foundation

class PhoneNumberDataSource {
    
    private(set) var territories = [MetadataPhoneNumberTerritory]()

    private var territoriesByCode = [UInt64: [MetadataPhoneNumberTerritory]]()
    private var mainTerritoryByCode = [UInt64: MetadataPhoneNumberTerritory]()
    private var territoriesByCountry = [String: MetadataPhoneNumberTerritory]()
    
    init() {
        guard
            let jsonPath = Bundle.main.path(forResource: "PhoneNumberMetadata", ofType: "json"),
            let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
            let metadata = try? JSONDecoder().decode(PhoneNumberMetadata.self, from: jsonData)
        else {
            return
        }
        territories = metadata.territories
        for territory in territories {
            var currentTerritories: [MetadataPhoneNumberTerritory] = territoriesByCode[territory.countryCode] ?? []
            if territory.mainCountryForCode {
                currentTerritories.insert(territory, at: 0)
            } else {
                currentTerritories.append(territory)
            }
            territoriesByCode[territory.countryCode] = currentTerritories
            if mainTerritoryByCode[territory.countryCode] == nil || territory.mainCountryForCode == true {
                mainTerritoryByCode[territory.countryCode] = territory
            }
            territoriesByCountry[territory.codeID] = territory
        }
    }
    
    func filterTerritories(byCode code: UInt64) -> [MetadataPhoneNumberTerritory]? {
        territoriesByCode[code]
    }
    
    func filterTerritories(byCountry country: String) -> MetadataPhoneNumberTerritory? {
        territoriesByCountry[country.uppercased()]
    }
    
    func mainTerritory(forCode code: UInt64) -> MetadataPhoneNumberTerritory? {
        mainTerritoryByCode[code]
    }
    
}
