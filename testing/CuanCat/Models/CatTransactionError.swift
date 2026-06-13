import Foundation

// MARK: - Cat Transaction Error
//
// Tipe error yang bisa dilaporkan dari service eksternal ke kucing overlay.
// Engine menerima tipe ini dan menentukan stress impact + voucher trigger
// yang sesuai secara internal.
//
// Usage dari service luar:
//   CatOverlayManager.shared.reportError(.gatewayTimeout)
//   CatOverlayManager.shared.reportError(.serverError)

public enum CatTransactionError {

    /// HTTP 504 Gateway Timeout — server-side fault.
    /// Trigger voucher lebih awal (stress >= 75) karena ini "salah kita".
    case gatewayTimeout

    /// HTTP 5xx non-504 — server error (500, 502, 503, dll).
    case serverError

    /// Timeout / no connection — network issue di sisi client.
    case networkError

    /// HTTP 4xx — client fault (wrong input, unauthorized, etc.).
    /// Stress impact minimal karena ini bukan masalah performa.
    case clientError

    /// Error tidak terklasifikasi.
    case unknown
}
