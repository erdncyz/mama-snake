import Foundation

struct CaptureAward: Equatable, Identifiable {
    let id: Int
    let cells: Int
    let points: Int
    let isBigCapture: Bool
    let hasOvershoot: Bool

    static func scoring(
        cells: Int,
        level: Int,
        previousPercent: Float,
        newPercent: Float,
        totalPlayable: Int,
        targetPercent: Float,
        id: Int
    ) -> CaptureAward {
        let safeLevel = max(1, level)
        let previousFilled = min(
            totalPlayable,
            max(0, Int((previousPercent / 100) * Float(totalPlayable)))
        )
        let remaining = max(0, totalPlayable - previousFilled)
        let isBigCapture = cells >= LevelRules.bigCaptureThreshold(remainingCells: remaining)

        var points = cells * LevelRules.pointsPerCell * safeLevel
        if isBigCapture {
            points = (points * 3) / 2
        }

        let extraPercent = max(0, Int(newPercent - targetPercent))
        let hasOvershoot = previousPercent < targetPercent && extraPercent > 0
        if hasOvershoot {
            points += extraPercent * LevelRules.overshootPointsPerPercent * safeLevel
        }

        return CaptureAward(
            id: id,
            cells: cells,
            points: points,
            isBigCapture: isBigCapture,
            hasOvershoot: hasOvershoot
        )
    }
}
