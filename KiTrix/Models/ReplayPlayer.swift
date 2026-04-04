import Foundation

struct ReplayPlayer: Identifiable {
    let id: Int
    var userID: String = ""
    var displayName: String = ""
    var secondaryName: String = ""
    var gearData: Data = Data()
    var species: Int = 0
    var hairStyle: Int = 0
    var weaponTableIndex: Int = 0

    var speciesName: String {
        switch species {
        case 1: return "Inkling"
        case 2: return "Octoling"
        default: return "Unknown"
        }
    }
}
