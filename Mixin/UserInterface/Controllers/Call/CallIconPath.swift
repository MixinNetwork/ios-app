import Foundation

enum CallIconPath {
    
    static let speaker: UIBezierPath = {
        let path = UIBezierPath()
        
        path.move(to: CGPoint(x: 9.86, y: 0.93))
        path.addLine(to: CGPoint(x: 4.35, y: 5.75))
        path.addLine(to: CGPoint(x: 1.85, y: 5.75))
        path.addCurve(to: CGPoint(x: 0.35, y: 7.25),
                      controlPoint1: CGPoint(x: 1.02, y: 5.75),
                      controlPoint2: CGPoint(x: 0.35, y: 6.42))
        path.addLine(to: CGPoint(x: 0.35, y: 12.75))
        path.addCurve(to: CGPoint(x: 1.85, y: 14.25),
                      controlPoint1: CGPoint(x: 0.35, y: 13.58),
                      controlPoint2: CGPoint(x: 1.02, y: 14.25))
        path.addLine(to: CGPoint(x: 4.35, y: 14.25))
        path.addLine(to: CGPoint(x: 9.86, y: 19.07))
        path.addCurve(to: CGPoint(x: 12.35, y: 17.94),
                      controlPoint1: CGPoint(x: 10.83, y: 19.92),
                      controlPoint2: CGPoint(x: 12.35, y: 19.23))
        path.addLine(to: CGPoint(x: 12.35, y: 2.06))
        path.addCurve(to: CGPoint(x: 9.86, y: 0.93),
                      controlPoint1: CGPoint(x: 12.35, y: 0.77),
                      controlPoint2: CGPoint(x: 10.83, y: 0.08))
        path.close()
        path.move(to: CGPoint(x: 17.16, y: 3.99))
        path.addCurve(to: CGPoint(x: 19.65, y: 10),
                      controlPoint1: CGPoint(x: 18.75, y: 5.57),
                      controlPoint2: CGPoint(x: 19.65, y: 7.71))
        path.addCurve(to: CGPoint(x: 17.16, y: 16.01),
                      controlPoint1: CGPoint(x: 19.65, y: 12.29),
                      controlPoint2: CGPoint(x: 18.75, y: 14.43))
        path.addCurve(to: CGPoint(x: 17.16, y: 17.42),
                      controlPoint1: CGPoint(x: 16.77, y: 16.4),
                      controlPoint2: CGPoint(x: 16.77, y: 17.03))
        path.addCurve(to: CGPoint(x: 18.58, y: 17.42),
                      controlPoint1: CGPoint(x: 17.55, y: 17.81),
                      controlPoint2: CGPoint(x: 18.19, y: 17.81))
        path.addCurve(to: CGPoint(x: 21.65, y: 10),
                      controlPoint1: CGPoint(x: 20.53, y: 15.47),
                      controlPoint2: CGPoint(x: 21.65, y: 12.82))
        path.addCurve(to: CGPoint(x: 18.58, y: 2.58),
                      controlPoint1: CGPoint(x: 21.65, y: 7.18),
                      controlPoint2: CGPoint(x: 20.53, y: 4.53))
        path.addCurve(to: CGPoint(x: 17.16, y: 2.58),
                      controlPoint1: CGPoint(x: 18.19, y: 2.19),
                      controlPoint2: CGPoint(x: 17.55, y: 2.19))
        path.addCurve(to: CGPoint(x: 17.16, y: 3.99),
                      controlPoint1: CGPoint(x: 16.77, y: 2.97),
                      controlPoint2: CGPoint(x: 16.77, y: 3.6))
        path.close()
        path.move(to: CGPoint(x: 14.33, y: 6.82))
        path.addCurve(to: CGPoint(x: 15.65, y: 10),
                      controlPoint1: CGPoint(x: 15.17, y: 7.66),
                      controlPoint2: CGPoint(x: 15.65, y: 8.79))
        path.addCurve(to: CGPoint(x: 14.33, y: 13.18),
                      controlPoint1: CGPoint(x: 15.65, y: 11.21),
                      controlPoint2: CGPoint(x: 15.17, y: 12.34))
        path.addCurve(to: CGPoint(x: 14.33, y: 14.6),
                      controlPoint1: CGPoint(x: 13.94, y: 13.57),
                      controlPoint2: CGPoint(x: 13.94, y: 14.21))
        path.addCurve(to: CGPoint(x: 15.75, y: 14.6),
                      controlPoint1: CGPoint(x: 14.73, y: 14.99),
                      controlPoint2: CGPoint(x: 15.36, y: 14.99))
        path.addCurve(to: CGPoint(x: 17.65, y: 10),
                      controlPoint1: CGPoint(x: 16.96, y: 13.39),
                      controlPoint2: CGPoint(x: 17.65, y: 11.75))
        path.addCurve(to: CGPoint(x: 15.75, y: 5.4),
                      controlPoint1: CGPoint(x: 17.65, y: 8.25),
                      controlPoint2: CGPoint(x: 16.96, y: 6.61))
        path.addCurve(to: CGPoint(x: 14.33, y: 5.4),
                      controlPoint1: CGPoint(x: 15.36, y: 5.01),
                      controlPoint2: CGPoint(x: 14.73, y: 5.01))
        path.addCurve(to: CGPoint(x: 14.33, y: 6.82),
                      controlPoint1: CGPoint(x: 13.94, y: 5.79),
                      controlPoint2: CGPoint(x: 13.94, y: 6.43))
        path.close()
        path.usesEvenOddFillRule = true
        
        return path
    }()
    
    static let mute: UIBezierPath = {
        let path = UIBezierPath()
        
        path.move(to: CGPoint(x: 15.32, y: 10.64))
        path.addCurve(to: CGPoint(x: 15.4, y: 9.78),
                      controlPoint1: CGPoint(x: 15.37, y: 10.36),
                      controlPoint2: CGPoint(x: 15.4, y: 10.07))
        path.addLine(to: CGPoint(x: 15.4, y: 4.89))
        path.addCurve(to: CGPoint(x: 10.4, y: 0),
                      controlPoint1: CGPoint(x: 15.4, y: 2.19),
                      controlPoint2: CGPoint(x: 13.16, y: 0))
        path.addCurve(to: CGPoint(x: 6.46, y: 1.88),
                      controlPoint1: CGPoint(x: 8.8, y: 0),
                      controlPoint2: CGPoint(x: 7.37, y: 0.74))
        path.addCurve(to: CGPoint(x: 6.51, y: 2.65),
                      controlPoint1: CGPoint(x: 6.27, y: 2.11),
                      controlPoint2: CGPoint(x: 6.29, y: 2.44))
        path.addLine(to: CGPoint(x: 14.81, y: 10.8))
        path.addCurve(to: CGPoint(x: 15.24, y: 10.8),
                      controlPoint1: CGPoint(x: 14.93, y: 10.91),
                      controlPoint2: CGPoint(x: 15.12, y: 10.92))
        path.addCurve(to: CGPoint(x: 15.32, y: 10.64),
                      controlPoint1: CGPoint(x: 15.28, y: 10.76),
                      controlPoint2: CGPoint(x: 15.31, y: 10.7))
        path.close()
        path.move(to: CGPoint(x: 5.4, y: 7.07))
        path.addLine(to: CGPoint(x: 0.29, y: 2.05))
        path.addCurve(to: CGPoint(x: 0.29, y: 0.67),
                      controlPoint1: CGPoint(x: -0.1, y: 1.67),
                      controlPoint2: CGPoint(x: -0.1, y: 1.05))
        path.addCurve(to: CGPoint(x: 1.71, y: 0.67),
                      controlPoint1: CGPoint(x: 0.69, y: 0.29),
                      controlPoint2: CGPoint(x: 1.32, y: 0.29))
        path.addLine(to: CGPoint(x: 20.71, y: 19.33))
        path.addCurve(to: CGPoint(x: 20.71, y: 20.72),
                      controlPoint1: CGPoint(x: 21.1, y: 19.72),
                      controlPoint2: CGPoint(x: 21.1, y: 20.33))
        path.addCurve(to: CGPoint(x: 19.29, y: 20.71),
                      controlPoint1: CGPoint(x: 20.31, y: 21.1),
                      controlPoint2: CGPoint(x: 19.68, y: 21.09))
        path.addLine(to: CGPoint(x: 14.73, y: 16.24))
        path.addCurve(to: CGPoint(x: 10.4, y: 17.5),
                      controlPoint1: CGPoint(x: 13.46, y: 17.06),
                      controlPoint2: CGPoint(x: 11.97, y: 17.5))
        path.addCurve(to: CGPoint(x: 2.5, y: 9.78),
                      controlPoint1: CGPoint(x: 6.04, y: 17.5),
                      controlPoint2: CGPoint(x: 2.5, y: 14.04))
        path.addCurve(to: CGPoint(x: 3.4, y: 8.9),
                      controlPoint1: CGPoint(x: 2.5, y: 9.29),
                      controlPoint2: CGPoint(x: 2.9, y: 8.9))
        path.addCurve(to: CGPoint(x: 4.3, y: 9.78),
                      controlPoint1: CGPoint(x: 3.9, y: 8.9),
                      controlPoint2: CGPoint(x: 4.3, y: 9.29))
        path.addCurve(to: CGPoint(x: 10.4, y: 15.74),
                      controlPoint1: CGPoint(x: 4.3, y: 13.07),
                      controlPoint2: CGPoint(x: 7.03, y: 15.74))
        path.addCurve(to: CGPoint(x: 13.43, y: 14.96),
                      controlPoint1: CGPoint(x: 11.48, y: 15.74),
                      controlPoint2: CGPoint(x: 12.52, y: 15.47))
        path.addLine(to: CGPoint(x: 12.62, y: 14.16))
        path.addCurve(to: CGPoint(x: 10.4, y: 14.67),
                      controlPoint1: CGPoint(x: 11.95, y: 14.48),
                      controlPoint2: CGPoint(x: 11.2, y: 14.67))
        path.addCurve(to: CGPoint(x: 5.4, y: 9.78),
                      controlPoint1: CGPoint(x: 7.64, y: 14.67),
                      controlPoint2: CGPoint(x: 5.4, y: 12.48))
        path.addLine(to: CGPoint(x: 5.4, y: 7.07))
        path.close()
        path.move(to: CGPoint(x: 13.42, y: 18.58))
        path.addCurve(to: CGPoint(x: 14.4, y: 19.56),
                      controlPoint1: CGPoint(x: 13.96, y: 18.58),
                      controlPoint2: CGPoint(x: 14.4, y: 19.02))
        path.addCurve(to: CGPoint(x: 13.42, y: 20.53),
                      controlPoint1: CGPoint(x: 14.4, y: 20.1),
                      controlPoint2: CGPoint(x: 13.96, y: 20.53))
        path.addLine(to: CGPoint(x: 7.38, y: 20.53))
        path.addCurve(to: CGPoint(x: 6.4, y: 19.56),
                      controlPoint1: CGPoint(x: 6.84, y: 20.53),
                      controlPoint2: CGPoint(x: 6.4, y: 20.1))
        path.addCurve(to: CGPoint(x: 7.38, y: 18.58),
                      controlPoint1: CGPoint(x: 6.4, y: 19.02),
                      controlPoint2: CGPoint(x: 6.84, y: 18.58))
        path.addLine(to: CGPoint(x: 13.42, y: 18.58))
        path.close()
        path.move(to: CGPoint(x: 17.4, y: 8.9))
        path.addCurve(to: CGPoint(x: 18.3, y: 9.78),
                      controlPoint1: CGPoint(x: 17.9, y: 8.9),
                      controlPoint2: CGPoint(x: 18.3, y: 9.29))
        path.addCurve(to: CGPoint(x: 17.95, y: 12.05),
                      controlPoint1: CGPoint(x: 18.3, y: 10.56),
                      controlPoint2: CGPoint(x: 18.18, y: 11.32))
        path.addCurve(to: CGPoint(x: 16.83, y: 12.63),
                      controlPoint1: CGPoint(x: 17.81, y: 12.51),
                      controlPoint2: CGPoint(x: 17.3, y: 12.77))
        path.addCurve(to: CGPoint(x: 16.23, y: 11.53),
                      controlPoint1: CGPoint(x: 16.35, y: 12.49),
                      controlPoint2: CGPoint(x: 16.09, y: 12))
        path.addCurve(to: CGPoint(x: 16.5, y: 9.78),
                      controlPoint1: CGPoint(x: 16.41, y: 10.97),
                      controlPoint2: CGPoint(x: 16.5, y: 10.38))
        path.addCurve(to: CGPoint(x: 17.4, y: 8.9),
                      controlPoint1: CGPoint(x: 16.5, y: 9.29),
                      controlPoint2: CGPoint(x: 16.9, y: 8.9))
        path.close()
        path.usesEvenOddFillRule = true
        
        return path
    }()
    
}
