import Foundation

struct InkActionDecoder {
    static func decode(blob: [UInt8], weaponClass: WeaponClass, playerIndex: Int = -1, status: EntityStatus = .normal) -> InkActionState {
        guard blob.count >= 9 else { return .none }

        let frameFlags = UInt64(blob[0]) | (UInt64(blob[1]) << 8)
        let shortFlags: UInt16 = {
            if blob.count >= 31 {
                return UInt16(blob[29]) | (UInt16(blob[30]) << 8)
            }
            return 0
        }()
        let stateByte = blob.count > 31 ? blob[blob.count - 1] : 0
        let inkByte = blob.count > 31 ? blob[min(31, blob.count - 1)] : 0

        if status == .absent { return .none }
        if shortFlags == 0 && frameFlags == 0 && stateByte == 0 && inkByte == 0 && playerIndex < 0 { return .none }

        var rawBits = Array(blob.suffix(min(16, blob.count)))
        if rawBits.count < 16 {
            rawBits.append(contentsOf: repeatElement(0, count: 16 - rawBits.count))
        }

        let firingPrimary = (shortFlags & 0x01) != 0
        let weaponActive = shortFlags != 0 || frameFlags != 0
        let firingFromSpread = (inkByte & 0x01) != 0
        let secondaryFire = (inkByte & 0x02) != 0
        let thirdByte = (status == .full) ? 0x80 : 0
        let chargeRaw = max(0, Int(stateByte) - thirdByte)
        let chargeLevel = weaponClass == .charger ? min(1.0, Float(chargeRaw) / 255.0) : 0.0
        let swingPhase = stateByte & 0x03
        let slashPhase = (stateByte >> 2) & 0x03

        guard weaponActive || firingFromSpread || secondaryFire || chargeLevel > 0 || status == .full else { return .none }

        switch weaponClass {
        case .shooter:
            return .shooter(.init(isFiring: firingPrimary || firingFromSpread, shotTimer: shortFlags))
        case .blaster:
            return .shooter(.init(isFiring: firingPrimary || firingFromSpread, shotTimer: shortFlags))
        case .charger:
            let isCharging = firingPrimary || firingFromSpread || chargeLevel > 0.03
            return .charger(.init(isCharging: isCharging, chargeLevel: max(0, chargeLevel), isFullCharge: chargeLevel >= 0.98))
        case .roller:
            return .roller(.init(isRolling: firingPrimary || firingFromSpread, isFling: secondaryFire))
        case .brush:
            return .brush(.init(isSwinging: firingPrimary || firingFromSpread, isRunning: secondaryFire))
        case .slosher:
            return .slosher(.init(swingPhase: swingPhase))
        case .maneuver:
            return .maneuver(.init(isFiring: firingPrimary || firingFromSpread, dodgeRollState: stateByte))
        case .spinner:
            return .spinner(.init(isSpunUp: secondaryFire, isFiring: firingPrimary || firingFromSpread))
        case .shelter:
            return .shelter(.init(isShieldDeployed: secondaryFire, isFiring: firingPrimary || firingFromSpread))
        case .stringer:
            return .stringer(.init(drawLevel: min(1.0, Float(chargeRaw) / 180.0), isReleased: firingPrimary || firingFromSpread))
        case .saber:
            return .saber(.init(slashPhase: slashPhase, isCharged: secondaryFire))
        case .unknown:
            return .unknown(rawBits: Array(rawBits))
        }
    }
}
