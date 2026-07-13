import Foundation

// MARK: - Cat Animation Type

enum CatAnimationType: String, CaseIterable {
    case idle
    case warmup
    case pushup
    case starJump
    case walk
    case annoyed
    case sad
    case happy
    case exhausted

    /// Hanya rest exercise (warmup/pushup/starJump), idle, dan walk yang
    /// LOOP. Reaction (annoyed/sad/happy/exhausted) main SEKALI saja.
    var loops: Bool {
        switch self {
        case .idle, .warmup, .pushup, .starJump, .walk:
            return true
        case .annoyed, .sad, .happy, .exhausted:
            return false
        }
    }

    var description: String {
        switch self {
        case .idle:      return "Default idle breathing/standing (LOOP)"
        case .warmup:    return "Warmup exercise, rest variant (LOOP)"
        case .pushup:    return "Push up exercise, rest variant (LOOP)"
        case .starJump:  return "Star jump exercise, rest variant (LOOP)"
        case .walk:      return "Walking, flip horizontally for left (LOOP)"
        case .annoyed:   return "Annoyed reaction, transaction failed (ONCE)"
        case .sad:       return "Sad reaction, transaction failed variant (ONCE)"
        case .happy:     return "Happy celebration, transaction success (ONCE)"
        case .exhausted: return "Exhausted, loading > 10s (ONCE)"
        }
    }

    /// Urutan preload — rest pool duluan karena jadi tampilan default awal.
    var loadPriority: Int {
        switch self {
        case .warmup:    return 0
        case .pushup:    return 1
        case .starJump:  return 2
        case .idle:      return 3
        case .walk:      return 4
        case .annoyed:   return 5
        case .sad:       return 6
        case .happy:     return 7
        case .exhausted: return 8
        }
    }
}
