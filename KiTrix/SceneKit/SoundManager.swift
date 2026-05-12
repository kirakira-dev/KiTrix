import Foundation
import AppKit

class SoundManager {
    static let shared = SoundManager()
    private var isEnabled = true
    
    func playShotSound(weaponClass: WeaponClass) {
        guard isEnabled else { return }
        // Use NSSound for simple beep variations based on weapon
        let soundNames = [
            "shooter": "Ping",
            "blaster": "Blow",
            "charger": "Pop",
            "roller": "Frog",
            "brush": "Hero",
            "slosher": "Bottle",
            "spinner": "Morse",
            "shelter": "Glass",
            "stringer": "Hero",
            "saber": "Ping"
        ]
        let name = soundNames[weaponClass.rawValue] ?? "Ping"
        if let sound = NSSound(named: name) {
            sound.play()
        }
    }
    
    func playSplatSound() {
        guard isEnabled else { return }
        if let sound = NSSound(named: "Basso") {
            sound.play()
        }
    }
    
    func playExplosionSound() {
        guard isEnabled else { return }
        if let sound = NSSound(named: "Blow") {
            sound.play()
        }
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
}
