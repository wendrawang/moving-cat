import Foundation

// MARK: - Cat Asset Manifest
//
// 9 animasi = 9 file .json (Lottie).
//
// Steps:
//   1. Add .json files ke Xcode project (Build Phases → Copy Bundle Resources)
//   2. Update filename strings di bawah jika perlu

enum CatAssetManifest {

    static let idle      = "cat_idle"
    static let warmup    = "cat_warmup"
    static let pushup    = "cat_pushup"
    static let starJump  = "cat_starjump"
    static let walk      = "cat_walk"
    static let annoyed   = "cat_annoyed"
    static let sad       = "cat_sad"
    static let happy     = "cat_happy"
    static let exhausted = "cat_exhausted"

    static let fileExtension = "json"

    // MARK: - Lookup API

    static func assetName(animation: CatAnimationType) -> String {
        switch animation {
        case .idle:      return idle
        case .warmup:    return warmup
        case .pushup:    return pushup
        case .starJump:  return starJump
        case .walk:      return walk
        case .annoyed:   return annoyed
        case .sad:       return sad
        case .happy:     return happy
        case .exhausted: return exhausted
        }
    }

    static func fileName(animation: CatAnimationType) -> String {
        return "\(assetName(animation: animation)).\(fileExtension)"
    }

    // MARK: - Validation

    static func validateAssets() -> [String] {
        var missing: [String] = []
        for anim in CatAnimationType.allCases {
            let name = assetName(animation: anim)
            let inBundle = Bundle.main.url(
                forResource: name, withExtension: fileExtension
            ) != nil
            if !inBundle {
                missing.append("\(name).\(fileExtension)")
            }
        }
        return missing
    }
}
