import XCTest

class PhotoDisplayTests: XCTestCase {
    
    func testPhotoSizeCalculation() {
        let contentSizes: [CGSize] = [
            // Bad input
            CGSize(width: 1, height: 1),
            
            // General photos
            CGSize(width: 3024, height: 4032),
            CGSize(width: 4032, height: 3024),
            
            // Panoramas
            CGSize(width: 11344, height: 3916),
            CGSize(width: 3916, height: 11344),
            
            // Article
            CGSize(width: 900, height: 30000),
            
            // Irregular shapes
            CGSize(width: 400, height: 1000),
            CGSize(width: 180, height: 1000),
            CGSize(width: 110, height: 1000),
            
            CGSize(width: 400, height: 200),
            CGSize(width: 180, height: 200),
            CGSize(width: 110, height: 200),
            
            CGSize(width: 400, height: 100),
            CGSize(width: 180, height: 100),
            CGSize(width: 110, height: 100),
            CGSize(width: 90, height: 100),
        ]
        
        let expected = [
            // Bad input
            CGSize(width: 120, height: 120),
            
            // General photos
            CGSize(width: 210, height: 280),
            CGSize(width: 210, height: 158),
            
            // Panoramas
            CGSize(width: 210, height: 120),
            CGSize(width: 97, height: 280),
            
            // Article
            CGSize(width: 8, height: 280),
            
            // Irregular shapes
            CGSize(width: 112, height: 280),
            CGSize(width: 120, height: 280),
            CGSize(width: 120, height: 280),
            
            CGSize(width: 210, height: 120),
            CGSize(width: 180, height: 200),
            CGSize(width: 120, height: 218),
            
            CGSize(width: 210, height: 120),
            CGSize(width: 210, height: 120),
            CGSize(width: 132, height: 120),
            CGSize(width: 120, height: 133),
        ]
        
        let calculated = contentSizes.map(PhotoSizeCalculator.displaySize(for:))
        XCTAssertEqual(calculated.count, expected.count)
        for i in 0..<calculated.count {
            XCTAssertEqual(calculated[i], expected[i])
        }
    }
    
}
