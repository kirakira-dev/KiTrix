import Foundation

struct PlayerMatchStats {
    var kills: Int = 0
    var deaths: Int = 0
    var inkPainted: Float = 0
    var specialCharges: Int = 0
    var specialUsed: Int = 0
    var weaponClass: String = ""
    var displayName: String = ""
    var teamIndex: Int = 0
}

class MatchStatsTracker {
    static let shared = MatchStatsTracker()
    private(set) var playerStats: [UInt32: PlayerMatchStats] = [:]
    private var lastSpecialCharges: [UInt32: Float] = [:]
    
    func reset() {
        playerStats.removeAll()
        lastSpecialCharges.removeAll()
    }
    
    func registerPlayer(entityID: UInt32, name: String, teamIndex: Int, weaponClass: String) {
        var stats = PlayerMatchStats()
        stats.displayName = name
        stats.teamIndex = teamIndex
        stats.weaponClass = weaponClass
        playerStats[entityID] = stats
    }
    
    func recordKill(killerID: UInt32, victimID: UInt32) {
        playerStats[killerID]?.kills += 1
        playerStats[victimID]?.deaths += 1
    }
    
    func recordInkPainted(entityID: UInt32, amount: Float) {
        playerStats[entityID]?.inkPainted += amount
    }
    
    func updateSpecialCharge(entityID: UInt32, charge: Float) {
        let lastCharge = lastSpecialCharges[entityID] ?? 0
        if charge >= PlayerNode.specialThreshold && lastCharge < PlayerNode.specialThreshold {
            playerStats[entityID]?.specialCharges += 1
        }
        lastSpecialCharges[entityID] = charge
    }
    
    func getTeamInkPercentage(teamIndex: Int, accumulator: InkAccumulator) -> Double {
        return accumulator.inkPercentage(forTeam: teamIndex)
    }
    
    func sortedPlayers(forTeam teamIndex: Int) -> [PlayerMatchStats] {
        return playerStats.values
            .filter { $0.teamIndex == teamIndex }
            .sorted { $0.kills > $1.kills }
    }
}