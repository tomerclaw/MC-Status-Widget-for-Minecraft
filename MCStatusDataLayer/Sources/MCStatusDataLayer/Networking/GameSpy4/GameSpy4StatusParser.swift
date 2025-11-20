//
//  JavaServerStatusParser.swift
//  MCStatus
//
//  Created by Tomer Shemesh on 7/30/23.
//

import Foundation

public class GameSpy4StatusParser: ServerStatusParserProtocol {
    
    // parsing logic reimplemented from https://github.com/xPaw/PHP-Minecraft-Query/blob/ce243feb85db64a198a05c25803d588fa025f524/src/MinecraftQuery.php#L116
    public static func parseServerResponse(input: Data, config: ServerCheckerConfig?) throws -> ServerStatus {
        // Work on a mutable copy
        var data = input

        // Require at least 16 bytes for the status header
        guard data.count > 16 else {
            print("Response too short for status header")
            throw ServerStatusCheckerError.StatusUnparsable
        }
        data = data.dropFirst(16)

        // Build separator: 00 00 01 'player_' 00 00
        var sep = Data([0x00, 0x00, 0x01])
        sep.append("player_".data(using: .ascii)!)
        sep.append(contentsOf: [0x00, 0x00])

        guard let range = data.range(of: sep) else {
            print("Failed to find player separator")
            throw ServerStatusCheckerError.StatusUnparsable
        }

        let headerData = Data(data[..<range.lowerBound])
        var playersData = Data(data[range.upperBound...])

        // PHP code did substr(..., 0, -2) on players part -> drop last two bytes if present
        if playersData.count >= 2 {
            playersData.removeLast(2)
        }

        // Split by NUL and decode
        let headerParts = headerData.split(separator: 0x00, omittingEmptySubsequences: false).map { Data($0) }
            .map { String(data: $0, encoding: .isoLatin1) ?? "" }

        var info: [String: Any] = [:]

        // Iterate as key/value pairs (even index = key, odd = value)
        var i = 0
        while i + 1 < headerParts.count {
            let key = headerParts[i]
            let val = headerParts[i + 1]
            i += 2

            info[key] = val
        }
        
        var status = ServerStatus()
        status.status = .Online
        status.source = .GameSpy4
        if let maxPlayers = info["maxplayers"] as? String, let maxPlayersInt = Int(maxPlayers) {
            status.maxPlayerCount = maxPlayersInt
        }
        
        if let onlinePlayers = info["numplayers"] as? String, let onlinePlayersInt = Int(onlinePlayers) {
            status.onlinePlayerCount = onlinePlayersInt
        }
        
        if let version = info["version"] as? String {
            status.version = version
        }
        
        // motd (hostname)
        // player sample

        // Parse players list
        let players: [String]
        if playersData.isEmpty {
            players = []
        } else {
            players = playersData.split(separator: 0x00).map { Data($0) }
                .compactMap { String(data: $0, encoding: .isoLatin1) }
                .filter { !$0.isEmpty }
        }

//        print("=== Players (\(players.count)) ===")
//        for (idx, p) in players.enumerated() {
//            print("\(idx + 1): \(p)")
//        }
        
        return status
    }
}




