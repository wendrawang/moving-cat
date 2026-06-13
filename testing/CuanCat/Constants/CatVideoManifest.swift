import Foundation
import UIKit   // NSDataAsset

// MARK: - Cat Video Manifest
//
// Constants untuk .mov animation files.
//
// ⚠️  SENGAJA DIPISAH dari CatAssetManifest (.usdc) supaya tidak ada
//     kemungkinan collision dengan USDC / SceneKit pipeline.
//     Jangan gabungkan kedua manifest ini.
//
// Dua cara taruh file .mov (keduanya didukung, dicek otomatis):
//
//   A) Assets.xcassets  ← LEBIH DIREKOMENDASIKAN
//      - Buka Assets.xcassets di Xcode
//      - Klik (+) → New Data Set
//      - Rename jadi "cat_idle", "cat_walk", dst.
//      - Drag .mov ke slot "Universal"
//      - Xcode akan pack ke asset catalog → diakses via NSDataAsset
//
//   B) Copy Bundle Resources (cara lama)
//      - Drag .mov ke Project Navigator
//      - Centang "Copy items if needed" + target app
//      - Cek Build Phases → Copy Bundle Resources
//
// CatVideoAssetCache mencoba (A) dulu, fallback ke (B).
// Jalankan validateAssets() untuk debug mana yang ketemu.

enum CatVideoManifest {

    // MARK: - Asset Names (tanpa extension)
    //
    // Nama ini dipakai sebagai:
    //   - NSDataAsset name  (Assets.xcassets → Data Set name)
    //   - Bundle resource name (file .mov di bundle)
    //
    // Default sama seperti CatAssetManifest — ubah jika nama file berbeda.

    static let idle      = "cat_idle_movie"
    static let walk      = "cat_walk_movie"
    static let annoyed   = "cat_annoyed_movie"
    static let sad       = "cat_sad_movie"
    static let happy     = "cat_happy_movie"
    static let exhausted = "cat_exhausted_movie"

    /// File extension untuk video.
    /// BERBEDA dari CatAssetManifest.fileExtension ("usdc").
    static let fileExtension = "mov"

    // MARK: - Lookup

    static func assetName(for animation: CatAnimationType) -> String {
        switch animation {
        case .idle:      return idle
        case .walk:      return walk
        case .annoyed:   return annoyed
        case .sad:       return sad
        case .happy:     return happy
        case .exhausted: return exhausted
        }
    }

    /// URL file .mov dari bundle utama (cara B).
    /// Mengembalikan nil jika file tidak ada di bundle (mungkin di asset catalog).
    static func bundleURL(for animation: CatAnimationType) -> URL? {
        Bundle.main.url(
            forResource: assetName(for: animation),
            withExtension: fileExtension
        )
    }

    // MARK: - Validation

    /// Cek asset mana yang tidak ditemukan di kedua lokasi (catalog + bundle).
    ///
    /// ```swift
    /// let missing = CatVideoManifest.validateAssets()
    /// if !missing.isEmpty {
    ///     print("[CatVideo] Missing:", missing)
    /// }
    /// ```
    @discardableResult
    static func validateAssets() -> [String] {
        CatAnimationType.allCases.compactMap { anim -> String? in
            let name = assetName(for: anim)
            let inCatalog = NSDataAsset(name: name) != nil
            let inBundle  = bundleURL(for: anim) != nil
            guard !inCatalog && !inBundle else { return nil }
            return "\(name).\(fileExtension)"
        }
    }
}
