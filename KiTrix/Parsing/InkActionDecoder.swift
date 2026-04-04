import Foundation

struct InkActionDecoder {
    static func decode(blob: [UInt8], weaponClass: WeaponClass) -> InkActionState {
        guard blob.count >= 33 else { return .none }

        let weaponActive = UInt16(blob[29]) | (UInt16(blob[30]) << 8)
        let inkByte = blob[31]
        let stateByte = blob[32]

        guard weaponActive != 0 else { return .none }

        switch weaponClass {
        case .shooter:
            return .shooter(.init(isFiring: inkByte & 0x01 != 0, shotTimer: weaponActive))
        case .blaster:
            return .shooter(.init(isFiring: inkByte & 0x01 != 0, shotTimer: weaponActive))
        case .charger:
            let charging = inkByte & 0x01 != 0
            let level = Float(stateByte) / 255.0
            return .charger(.init(isCharging: charging, chargeLevel: level, isFullCharge: level >= 0.95))
        case .roller:
            return .roller(.init(isRolling: inkByte & 0x01 != 0, isFling: inkByte & 0x02 != 0))
        case .brush:
            return .brush(.init(isSwinging: inkByte & 0x01 != 0, isRunning: inkByte & 0x02 != 0))
        case .slosher:
            return .slosher(.init(swingPhase: stateByte & 0x03))
        case .maneuver:
            return .maneuver(.init(isFiring: inkByte & 0x01 != 0, dodgeRollState: stateByte & 0x03))
        case .spinner:
            return .spinner(.init(isSpunUp: inkByte & 0x02 != 0, isFiring: inkByte & 0x01 != 0))
        case .shelter:
            return .shelter(.init(isShieldDeployed: inkByte & 0x02 != 0, isFiring: inkByte & 0x01 != 0))
        case .stringer:
            let level = Float(stateByte) / 255.0
            return .stringer(.init(drawLevel: level, isReleased: inkByte & 0x01 != 0))
        case .saber:
            return .saber(.init(slashPhase: stateByte & 0x03, isCharged: inkByte & 0x02 != 0))
        case .unknown:
            return .unknown(rawBits: Array(blob[29..<min(33, blob.count)]))
        }
    }
}
