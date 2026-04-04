import Foundation

enum InkActionState {
    case none
    case shooter(ShooterState)
    case charger(ChargerState)
    case roller(RollerState)
    case brush(BrushState)
    case slosher(SlosherState)
    case maneuver(ManeuverState)
    case spinner(SpinnerState)
    case shelter(ShelterState)
    case stringer(StringerState)
    case saber(SaberState)
    case unknown(rawBits: [UInt8])

    struct ShooterState { let isFiring: Bool; let shotTimer: UInt16 }
    struct ChargerState { let isCharging: Bool; let chargeLevel: Float; let isFullCharge: Bool }
    struct RollerState { let isRolling: Bool; let isFling: Bool }
    struct BrushState { let isSwinging: Bool; let isRunning: Bool }
    struct SlosherState { let swingPhase: UInt8 }
    struct ManeuverState { let isFiring: Bool; let dodgeRollState: UInt8 }
    struct SpinnerState { let isSpunUp: Bool; let isFiring: Bool }
    struct ShelterState { let isShieldDeployed: Bool; let isFiring: Bool }
    struct StringerState { let drawLevel: Float; let isReleased: Bool }
    struct SaberState { let slashPhase: UInt8; let isCharged: Bool }

    var isFiring: Bool {
        switch self {
        case .none: return false
        case .shooter(let s): return s.isFiring
        case .charger(let s): return s.isFullCharge
        case .roller(let s): return s.isRolling || s.isFling
        case .brush(let s): return s.isSwinging || s.isRunning
        case .slosher(let s): return s.swingPhase == 2
        case .maneuver(let s): return s.isFiring
        case .spinner(let s): return s.isFiring
        case .shelter(let s): return s.isFiring
        case .stringer(let s): return s.isReleased
        case .saber(let s): return s.slashPhase > 0
        case .unknown: return false
        }
    }

    var chargeLevel: Float {
        switch self {
        case .charger(let s): return s.chargeLevel
        case .stringer(let s): return s.drawLevel
        default: return 1.0
        }
    }

    var isRolling: Bool {
        switch self {
        case .roller(let s): return s.isRolling
        case .brush(let s): return s.isRunning
        default: return false
        }
    }
}
