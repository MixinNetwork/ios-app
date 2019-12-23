import Foundation

public struct AssetSearchResult {
    
    static let highlightedAttributes: [NSAttributedString.Key: Any] = {
        var attrs = AssetCell.symbolAttributes
        attrs[.foregroundColor] = UIColor.highlightedText
        return attrs
    }()
    
    let attributedSymbol: NSMutableAttributedString?
    let asset: AssetItem
    
    init(asset: AssetItem, keyword: String) {
        self.asset = asset
        let range = (asset.symbol.lowercased() as NSString).range(of: keyword)
        if range.length != 0 {
            let str = NSMutableAttributedString(string: asset.symbol, attributes: AssetCell.symbolAttributes)
            str.setAttributes(AssetSearchResult.highlightedAttributes, range: range)
            self.attributedSymbol = str
        } else {
            self.attributedSymbol = nil
        }
    }
    
}
