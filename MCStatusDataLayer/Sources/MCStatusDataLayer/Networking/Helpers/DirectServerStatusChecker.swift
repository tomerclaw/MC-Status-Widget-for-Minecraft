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
            do {
                let gameSpyChecker = GameSpy4StatusChecker(serverAddress: serverUrl, port: serverPort)
                let gameSpyData = try await gameSpyChecker.checkServer()
                let gameSpyResult = try gameSpyChecker.getParser().parseServerResponse(input: gameSpyData, config: config)
                // Merge: replace player sample with the full list from GameSpy
                result.playerSample = gameSpyResult.playerSample
                // Update online player count if GameSpy reports a more accurate value
                if gameSpyResult.onlinePlayerCount > 0 {
                    result.onlinePlayerCount = gameSpyResult.onlinePlayerCount
                }
            } catch {
                // GameSpy query failed — silently fall back to the normal result, no crash
                print("GameSpy query failed, using normal result. Error: \(error)")
            }
        }

        print("Successful connection and parsing. returning result.")
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



