import Foundation

// MARK: - CatSoundType
//
// Setiap case memetakan ke file audio di bundle (<rawValue>.wav).
// Jika file tidak ada: type tersebut menjadi no-op secara otomatis.
// Untuk menambah sound baru: tambah case + taruh <rawValue>.wav di bundle.

enum CatSoundType: String, CaseIterable {
    case idle       = "cat_sound_idle"         // ambient purr loop saat idle
    case walk       = "cat_sound_walk"         // langkah kaki loop saat walking
    case happy      = "cat_sound_happy"        // celebrasi saat transaksi berhasil
    case sad        = "cat_sound_sad"          // sedih saat transaksi gagal (variant sad)
    case annoyed    = "cat_sound_annoyed"      // kesal saat transaksi gagal (variant annoyed)
    case exhausted  = "cat_sound_exhausted"    // kelelahan saat loading > 10s
    case tapMeow    = "cat_sound_tap_meow"     // meow saat di-tap tanpa voucher
    case tapVoucher = "cat_sound_tap_voucher"  // suara khusus saat di-tap ada voucher

    /// true = loop terus-menerus (idle, walk). false = play sekali.
    var loops: Bool {
        switch self {
        case .idle, .walk: return true
        default: return false
        }
    }

    /// Volume relatif. Loop ambient lebih pelan agar tidak mengganggu.
    var volume: Float {
        switch self {
        case .idle: return 0.3
        case .walk: return 0.5
        default:   return 1.0
        }
    }

    /// true = sound ini di-overlay di atas loop aktif (tidak stop loop).
    /// Tap sounds harus overlay agar walk/idle loop tetap berjalan saat user tap.
    var isOverlay: Bool {
        switch self {
        case .tapMeow, .tapVoucher: return true
        default: return false
        }
    }

    /// Urutan preload — tap & reaction duluan karena butuh latency terendah.
    var preloadPriority: Int {
        switch self {
        case .tapMeow:    return 0
        case .tapVoucher: return 1
        case .happy:      return 2
        case .annoyed:    return 3
        case .sad:        return 4
        case .exhausted:  return 5
        case .walk:       return 6
        case .idle:       return 7
        }
    }
}
