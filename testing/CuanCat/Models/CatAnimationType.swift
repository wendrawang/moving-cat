import Foundation

// MARK: - Cat Animation Type

enum CatAnimationType: String, CaseIterable {
    case idle
    case walk
    case annoyed
    case sad
    case happy
    case exhausted

    var loops: Bool {
        switch self {
        case .exhausted: return false
        default: return true
        }
    }

    var description: String {
        switch self {
        case .idle:      return "Default idle breathing/standing (LOOP)"
        case .walk:      return "Walking, flip horizontally for left (LOOP)"
        case .annoyed:   return "Annoyed reaction, transaction failed (LOOP)"
        case .sad:       return "Sad reaction, transaction failed variant (LOOP)"
        case .happy:     return "Happy celebration, transaction success (LOOP)"
        case .exhausted: return "Exhausted, loading > 10s (ONCE)"
        }
    }
    
    var loadPriority: Int {
        switch self {
        case .idle:      return 0
        case .walk:      return 1
        case .annoyed:   return 2
        case .sad:       return 3
        case .happy:     return 4
        case .exhausted: return 5
        }
    }
}
