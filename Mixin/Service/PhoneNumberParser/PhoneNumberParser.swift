import Contacts

class PhoneNumberParser {
    
    let dataSource = PhoneNumberDataSource()
    
    private let regexper = PhoneNumberRegexper()
    
    func parse(_ numberString: String, withRegion region: String = CNContactsUserDefaults.shared().countryCode) throws -> PhoneNumber {
        var numberStringWithPlus = numberString
        do {
            return try parse(numberString, region: region)
        } catch {
            if numberStringWithPlus.first != "+" {
                numberStringWithPlus = "+" + numberStringWithPlus
            }
        }
        return try parse(numberStringWithPlus, region: region)
    }
    
    func format(_ phoneNumber: PhoneNumber) -> String {
        "+\(phoneNumber.countryCode)\(phoneNumber.adjustedNationalNumber())"
    }
    
}

extension PhoneNumberParser {
    
    private func normalizePhoneNumber(_ number: String) -> String {
        regexper.stringByReplacingOccurrences(number, map: PhoneNumberPatterns.allNormalizationMappings)
    }
    
    private func isNumberMatchingDesc(_ nationalNumber: String, numberDesc: MetadataPhoneNumberDesc?) -> Bool {
        regexper.matchesEntirely(numberDesc?.nationalNumberPattern, string: nationalNumber)
    }
    
    private func stripNationalPrefix(_ number: inout String, metadata: MetadataPhoneNumberTerritory) {
        guard let possibleNationalPrefix = metadata.nationalPrefixForParsing else {
            return
        }
        let prefixPattern = "^(?:\(possibleNationalPrefix))"
        do {
            let matches = try regexper.regexMatches(prefixPattern, string: number)
            if let firstMatch = matches.first {
                let nationalNumberRule = metadata.generalDesc?.nationalNumberPattern
                let firstMatchString = number.substring(with: firstMatch.range)
                let numOfGroups = firstMatch.numberOfRanges - 1
                let firstRange = firstMatch.range(at: numOfGroups)
                let firstMatchStringWithGroup = (firstRange.location != NSNotFound && firstRange.location < number.count) ? number.substring(with: firstRange) : String()
                let firstMatchStringWithGroupHasValue = regexper.hasValue(firstMatchStringWithGroup)
                var transformedNumber: String = String()
                if let transformRule = metadata.nationalPrefixTransformRule, firstMatchStringWithGroupHasValue == true {
                    transformedNumber = regexper.replaceFirstStringByRegex(prefixPattern, string: number, templateString: transformRule)
                } else {
                    let index = number.index(number.startIndex, offsetBy: firstMatchString.count)
                    transformedNumber = String(number[index...])
                }
                if regexper.hasValue(nationalNumberRule), regexper.matchesEntirely(nationalNumberRule, string: number), regexper.matchesEntirely(nationalNumberRule, string: transformedNumber) == false {
                    return
                }
                number = transformedNumber
                return
            }
        } catch {
            return
        }
    }
    
    private func checkNumberType(_ nationalNumber: String, metadata: MetadataPhoneNumberTerritory, leadingZero: Bool = false) -> PhoneNumberType {
        if leadingZero {
            let type = checkNumberType("0" + String(nationalNumber), metadata: metadata)
            if type != .unknown {
                return type
            }
        }
        guard let generalNumberDesc = metadata.generalDesc else {
            return .unknown
        }
        if regexper.hasValue(generalNumberDesc.nationalNumberPattern) == false || isNumberMatchingDesc(nationalNumber, numberDesc: generalNumberDesc) == false {
            return .unknown
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.pager) {
            return .pager
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.premiumRate) {
            return .premiumRate
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.tollFree) {
            return .tollFree
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.sharedCost) {
            return .sharedCost
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.voip) {
            return .voip
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.personalNumber) {
            return .personalNumber
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.uan) {
            return .uan
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.voicemail) {
            return .voicemail
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.fixedLine) {
            if metadata.fixedLine?.nationalNumberPattern == metadata.mobile?.nationalNumberPattern {
                return .fixedOrMobile
            } else if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.mobile) {
                return .fixedOrMobile
            } else {
                return .fixedLine
            }
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.mobile) {
            return .mobile
        }
        return .unknown
    }
    
    private func validPhoneNumber(from nationalNumber: String, using regionMetadata: MetadataPhoneNumberTerritory, countryCode: UInt64, numberString: String, numberExtension: String?) throws -> PhoneNumber? {
        var nationalNumber = nationalNumber
        var regionMetadata = regionMetadata
        stripNationalPrefix(&nationalNumber, metadata: regionMetadata)
        if let generalNumberDesc = regionMetadata.generalDesc, regexper.hasValue(generalNumberDesc.nationalNumberPattern) == false || isNumberMatchingDesc(nationalNumber, numberDesc: generalNumberDesc) == false {
            return nil
        }
        let leadingZero = nationalNumber.hasPrefix("0")
        guard let finalNationalNumber = UInt64(nationalNumber) else {
            throw PhoneNumberError.notANumber
        }
        if let regionCode = getRegionCode(of: finalNationalNumber, countryCode: countryCode, leadingZero: leadingZero), let foundMetadata = dataSource.filterTerritories(byCountry: regionCode) {
            regionMetadata = foundMetadata
        }
        let type = checkNumberType(String(nationalNumber), metadata: regionMetadata, leadingZero: leadingZero)
        if type == .unknown {
            throw PhoneNumberError.unknownType
        }
        return PhoneNumber(numberString: numberString, countryCode: countryCode, leadingZero: leadingZero, nationalNumber: finalNationalNumber, numberExtension: numberExtension, type: type, regionID: regionMetadata.codeID)
    }
    
    private func extractCountryCode(_ number: String, nationalNumber: inout String, metadata: MetadataPhoneNumberTerritory) throws -> UInt64 {
        var fullNumber = number
        guard let possibleCountryIddPrefix = metadata.internationalPrefix else {
            return 0
        }
        let isDefaultCountryCode: Bool
        if regexper.matchesAtStart(PhoneNumberPatterns.leadingPlusCharsPattern, string: fullNumber) {
            fullNumber = regexper.replaceStringByRegex(PhoneNumberPatterns.leadingPlusCharsPattern, string: fullNumber)
            isDefaultCountryCode = false
        } else {
            fullNumber = normalizePhoneNumber(fullNumber)
            if parsePrefixAsIdd(&fullNumber, possibleCountryIddPrefix: possibleCountryIddPrefix) {
                isDefaultCountryCode = false
            } else {
                isDefaultCountryCode = true
            }
        }
        if !isDefaultCountryCode {
            if fullNumber.count <= PhoneNumberConstants.minLengthForNSN {
                throw PhoneNumberError.tooShort
            }
            return extractPotentialCountryCode(fullNumber, nationalNumber: &nationalNumber)
        } else {
            let defaultCountryCode = String(metadata.countryCode)
            if fullNumber.hasPrefix(defaultCountryCode) {
                let nsFullNumber = fullNumber as NSString
                var potentialNationalNumber = nsFullNumber.substring(from: defaultCountryCode.count)
                guard let validNumberPattern = metadata.generalDesc?.nationalNumberPattern, let possibleNumberPattern = metadata.generalDesc?.possibleNumberPattern else {
                    return 0
                }
                stripNationalPrefix(&potentialNationalNumber, metadata: metadata)
                let potentialNationalNumberStr = potentialNationalNumber
                if (!regexper.matchesEntirely(validNumberPattern, string: fullNumber) && regexper.matchesEntirely(validNumberPattern, string: potentialNationalNumberStr)) || regexper.testStringLengthAgainstPattern(possibleNumberPattern, string: fullNumber) == false {
                    nationalNumber = potentialNationalNumberStr
                    if let countryCode = UInt64(defaultCountryCode) {
                        return UInt64(countryCode)
                    }
                }
            }
        }
        return 0
    }
    
    private func parse(_ numberString: String, region: String) throws -> PhoneNumber {
        var nationalNumber = numberString
        let match = try regexper.phoneDataDetectorMatch(numberString)
        let matchedNumber = nationalNumber.substring(with: match.range)
        nationalNumber = regexper.stringByReplacingOccurrences(matchedNumber, map: PhoneNumberPatterns.allNormalizationMappings, keepUnmapped: true)
        let numberExtension: String?
        let matches = try? regexper.regexMatches(PhoneNumberPatterns.extnPattern, string: nationalNumber)
        if let match = matches?.first {
            let adjustedRange = NSRange(location: match.range.location + 1, length: match.range.length - 1)
            let rawExtension = nationalNumber.substring(with: adjustedRange)
            let stringRange = NSRange(location: 0, length: match.range.location)
            nationalNumber = nationalNumber.substring(with: stringRange)
            numberExtension = normalizePhoneNumber(rawExtension)
        } else {
            numberExtension = nil
        }
        guard var regionMetadata = dataSource.filterTerritories(byCountry: region.uppercased()) else {
            throw PhoneNumberError.invalidCountryCode
        }
        let countryCode: UInt64
        do {
            countryCode = try extractCountryCode(nationalNumber, nationalNumber: &nationalNumber, metadata: regionMetadata)
        } catch {
            let plusRemovedNumberString = regexper.replaceStringByRegex(PhoneNumberPatterns.leadingPlusCharsPattern, string: nationalNumber as String)
            countryCode = try extractCountryCode(plusRemovedNumberString, nationalNumber: &nationalNumber, metadata: regionMetadata)
        }
        nationalNumber = normalizePhoneNumber(nationalNumber)
        if countryCode == 0 {
            if let result = try validPhoneNumber(from: nationalNumber, using: regionMetadata, countryCode: regionMetadata.countryCode, numberString: numberString, numberExtension: numberExtension) {
                return result
            }
            throw PhoneNumberError.notANumber
        }
        if countryCode != regionMetadata.countryCode, let countryMetadata = dataSource.mainTerritory(forCode: countryCode) {
            regionMetadata = countryMetadata
        }
        if let result = try validPhoneNumber(from: nationalNumber, using: regionMetadata, countryCode: countryCode, numberString: numberString, numberExtension: numberExtension) {
            return result
        }
        var possibleResults = [PhoneNumber]()
        if let metadataList = dataSource.filterTerritories(byCode: countryCode) {
            for metadata in metadataList where regionMetadata.codeID != metadata.codeID {
                if let result = try validPhoneNumber(from: nationalNumber, using: metadata, countryCode: countryCode, numberString: numberString, numberExtension: numberExtension) {
                    possibleResults.append(result)
                }
            }
        }
        switch possibleResults.count {
        case 0:
            throw PhoneNumberError.notANumber
        case 1:
            return possibleResults[0]
        default:
            throw PhoneNumberError.ambiguousNumber(phoneNumbers: possibleResults)
        }
    }
    
    private func getRegionCode(of nationalNumber: UInt64, countryCode: UInt64, leadingZero: Bool) -> String? {
        guard let regions = dataSource.filterTerritories(byCode: countryCode) else {
            return nil
        }
        if regions.count == 1 {
            return regions[0].codeID
        }
        let nationalNumberString = String(nationalNumber)
        for region in regions {
            if let leadingDigits = region.leadingDigits {
                if regexper.matchesAtStart(leadingDigits, string: nationalNumberString) {
                    return region.codeID
                }
            }
            if leadingZero, checkNumberType("0" + nationalNumberString, metadata: region) != .unknown {
                return region.codeID
            }
            if checkNumberType(nationalNumberString, metadata: region) != .unknown {
                return region.codeID
            }
        }
        return nil
    }
    
    private func extractPotentialCountryCode(_ fullNumber: String, nationalNumber: inout String) -> UInt64 {
        let nsFullNumber = fullNumber as NSString
        if nsFullNumber.length == 0 || nsFullNumber.substring(to: 1) == "0" {
            return 0
        }
        let numberLength = nsFullNumber.length
        let maxCountryCode = PhoneNumberConstants.maxLengthCountryCode
        var startPosition = 0
        if fullNumber.hasPrefix("+") {
            if nsFullNumber.length == 1 {
                return 0
            }
            startPosition = 1
        }
        for i in 1...min(numberLength - startPosition, maxCountryCode) {
            let stringRange = NSRange(location: startPosition, length: i)
            let subNumber = nsFullNumber.substring(with: stringRange)
            if let potentialCountryCode = UInt64(subNumber), dataSource.filterTerritories(byCode: potentialCountryCode) != nil {
                nationalNumber = nsFullNumber.substring(from: i)
                return potentialCountryCode
            }
        }
        return 0
    }
    
    private func parsePrefixAsIdd(_ fullNumber: inout String, possibleCountryIddPrefix: String) -> Bool {
        if regexper.stringPositionByRegex(possibleCountryIddPrefix, string: fullNumber) == 0 {
            do {
                guard let matched = try regexper.regexMatches(possibleCountryIddPrefix, string: fullNumber as String).first else {
                    return false
                }
                let matchedString = fullNumber.substring(with: matched.range)
                let matchEnd = matchedString.count
                let remainString = (fullNumber as NSString).substring(from: matchEnd)
                let capturingDigitPatterns = try NSRegularExpression(pattern: PhoneNumberPatterns.capturingDigitPattern, options: NSRegularExpression.Options.caseInsensitive)
                let matchedGroups = capturingDigitPatterns.matches(in: remainString as String)
                if let firstMatch = matchedGroups.first {
                    let digitMatched = remainString.substring(with: firstMatch.range) as NSString
                    if digitMatched.length > 0 {
                        let normalizedGroup = regexper.stringByReplacingOccurrences(digitMatched as String, map: PhoneNumberPatterns.allNormalizationMappings)
                        if normalizedGroup == "0" {
                            return false
                        }
                    }
                }
                fullNumber = remainString as String
                return true
            } catch {
                return false
            }
        } else {
            return false
        }
    }
    
}
