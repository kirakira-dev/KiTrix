import Foundation

struct InkParams {
    let splatRadius: Float
    let fireInterval: Float
    let bulletSpeed: Float
    let gravity: Float
    let spreadAngle: Float
    let bulletLifetime: Float

    static func params(for weaponClass: WeaponClass) -> InkParams {
        switch weaponClass {
        case .shooter:
            return InkParams(splatRadius: 12.0, fireInterval: 0.03, bulletSpeed: 22.0, gravity: 12.0, spreadAngle: 3.0, bulletLifetime: 0.5)
        case .blaster:
            return InkParams(splatRadius: 18.0, fireInterval: 0.25, bulletSpeed: 15.0, gravity: 3.0, spreadAngle: 1.0, bulletLifetime: 0.6)
        case .charger:
            return InkParams(splatRadius: 7.0, fireInterval: 0.5, bulletSpeed: 60.0, gravity: 0.5, spreadAngle: 0.0, bulletLifetime: 0.8)
        case .roller:
            return InkParams(splatRadius: 22.0, fireInterval: 0.015, bulletSpeed: 0.0, gravity: 0.0, spreadAngle: 0.0, bulletLifetime: 0.1)
        case .brush:
            return InkParams(splatRadius: 14.0, fireInterval: 0.012, bulletSpeed: 0.0, gravity: 0.0, spreadAngle: 0.0, bulletLifetime: 0.1)
        case .slosher:
            return InkParams(splatRadius: 14.0, fireInterval: 0.25, bulletSpeed: 12.0, gravity: 15.0, spreadAngle: 8.0, bulletLifetime: 0.7)
        case .maneuver:
            return InkParams(splatRadius: 9.0, fireInterval: 0.03, bulletSpeed: 20.0, gravity: 10.0, spreadAngle: 4.0, bulletLifetime: 0.4)
        case .spinner:
            return InkParams(splatRadius: 9.0, fireInterval: 0.015, bulletSpeed: 25.0, gravity: 8.0, spreadAngle: 6.0, bulletLifetime: 0.4)
        case .shelter:
            return InkParams(splatRadius: 10.0, fireInterval: 0.08, bulletSpeed: 18.0, gravity: 10.0, spreadAngle: 10.0, bulletLifetime: 0.4)
        case .stringer:
            return InkParams(splatRadius: 8.0, fireInterval: 0.35, bulletSpeed: 40.0, gravity: 3.0, spreadAngle: 2.0, bulletLifetime: 0.6)
        case .saber:
            return InkParams(splatRadius: 18.0, fireInterval: 0.15, bulletSpeed: 10.0, gravity: 0.0, spreadAngle: 0.0, bulletLifetime: 0.3)
        case .unknown:
            return InkParams(splatRadius: 10.0, fireInterval: 0.08, bulletSpeed: 15.0, gravity: 10.0, spreadAngle: 5.0, bulletLifetime: 0.5)
        }
    }
}
