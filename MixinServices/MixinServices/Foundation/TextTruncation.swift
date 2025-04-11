import Foundation

public enum TextTruncation {
    
    public static func truncateMiddle(
        string: String,
        prefixCount: Int,
        suffixCount: Int
    ) -> String {
        if string.count > prefixCount + suffixCount {
            string.prefix(prefixCount) + "…" + string.suffix(suffixCount)
        } else {
            string
        }
    }
    
    public static func truncateTail(
        string: String,
        prefixCount: Int
    ) -> String {
        if string.count > prefixCount {
            string.prefix(prefixCount) + "…"
        } else {
            string
        }
    }
    
}
