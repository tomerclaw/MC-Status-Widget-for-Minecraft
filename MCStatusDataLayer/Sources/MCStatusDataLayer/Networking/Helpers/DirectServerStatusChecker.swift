//
//  ServerStatusChecker.swift
//  MCStatus
//
//  Created by Tomer Shemesh on 7/29/23.
//

import Foundation

public class DirectServerStatusChecker {
    public static func checkServer(serverUrl: String, serverPort: Int, serverType: ServerType, config: ServerCheckerConfig?) async throws -> ServerStatus {
        // 1. Always run the normal checker first to get the full result (MOTD, version, ping, icon, counts)
        let statusChecker = ServerStatusCheckerFactory().getStatusChecker(serverUrl: serverUrl, serverPort: serverPort, serverType: serverType)
        let resultData = try await statusChecker.checkServer()
        let result = try statusChecker.getParser().parseServerResponse(input: resultData, config: config)

        // 2. If GameSpy query is enabled and this is a Java server, also run GameSpy to get the full player list
        if (config?.useGameSpyQuery ?? false) && serverType == .Java {
            print("[GameSpy] Enabled for \(serverUrl):\(serverPort) — running full stat query")
            do {
                let gameSpyChecker = GameSpy4StatusChecker(serverAddress: serverUrl, port: serverPort)
                let gameSpyData = try await gameSpyChecker.checkServer()
                let gameSpyResult = try gameSpyChecker.getParser().parseServerResponse(input: gameSpyData, config: config)
                // Merge: replace player sample with the full list from GameSpy
                let previousCount = result.playerSample.count
                result.playerSample = gameSpyResult.playerSample
                if gameSpyResult.onlinePlayerCount > 0 {
                    result.onlinePlayerCount = gameSpyResult.onlinePlayerCount
                }
                print("[GameSpy] ✅ Success — player list updated: \(previousCount) → \(result.playerSample.count) players (\(result.playerSample.map { $0.name }.joined(separator: ", ")))")
            } catch {
                // GameSpy query failed — silently fall back to the normal result, no crash
                print("[GameSpy] ❌ Query failed for \(serverUrl):\(serverPort) — using normal result. Error: \(error)")
            }
        }

        print("[MCStatus] ✅ Status check complete for \(serverUrl) — \(result.onlinePlayerCount)/\(result.maxPlayerCount) online")
        return result
    }
}

//factory to dynamically handles creating the correct status checker for bedrock vs java
public class ServerStatusCheckerFactory {
    public func getStatusChecker(serverUrl: String, serverPort: Int, serverType: ServerType) -> ServerStatusCheckerProtocol {
        switch serverType {
        case .Java:
            JavaServerStatusChecker(serverAddress: serverUrl, port: serverPort)
        case .Bedrock:
            BedrockServerStatusChecker(serverAddress: serverUrl, port: serverPort)
        }
    }
}



