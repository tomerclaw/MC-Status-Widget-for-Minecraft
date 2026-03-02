//
//  MigrationHelper.swift
//  MCStatus
//
//  Created by Tomer Shemesh on 10/7/24.
//

import Foundation
import SwiftData
import MCStatusDataLayer

class MigrationHelper {
    
    static let VERSION = 2
    
    // returns nil if no migration, otherwie the current version that we just migratred to
    @MainActor static func migrationIfNeeded() -> (Int,Int)? {
        let lastVer = getLastVersion()
        if lastVer < VERSION {
            for i in lastVer...VERSION{
                runMigrationForVer(version: i)
            }
            setCurrentVersion(version: VERSION)
            return (lastVer,VERSION)
        } else {
            return nil
        }
    }
    
    
    @MainActor static func runMigrationForVer(version: Int) {
        switch version {
        case 0:
            migrateToV1()
        case 1:
            break // No data migration needed for v1→v2 path
        case 2:
            break // GameSpy release — handled separately as async operation (see runGameSpyAutoDetectionMigration)
        default:
            break
        }
    }
    
    @MainActor static func migrateToV1() {
        RealmDbMigrationHelper.shared.migrateServersToSwiftData()
    }
    
    
    static  func getLastVersion() -> Int {
        return  UserDefaults.standard.integer(forKey: "appVer")
    }
    
    static func setCurrentVersion(version: Int) {
        UserDefaults.standard.set(version, forKey: "appVer")
    }
    
    // MARK: - v3: GameSpy Auto-Detection Migration
    
    /// Runs once when upgrading to v3. For every Java server that doesn't already have
    /// GameSpy enabled, attempts a GameSpy query (2-second timeout). If the server
    /// responds, useGameSpyQuery is set to true and saved.
    /// Fully non-blocking — runs in a background detached task.
    static func runGameSpyAutoDetectionMigration(container: ModelContainer) {
        Task.detached(priority: .background) {
            print("[Migration v3] Starting GameSpy auto-detection for existing servers...")
            
            // Create a fresh context on this background task
            let context = ModelContext(container)
            
            let fetch = FetchDescriptor<SavedMinecraftServer>(
                sortBy: [.init(\.displayOrder)]
            )
            guard let servers = try? context.fetch(fetch) else {
                print("[Migration v3] Failed to fetch servers — skipping GameSpy migration")
                return
            }
            
            // Only process Java servers that haven't had GameSpy enabled yet
            let candidates = servers.filter { $0.serverType == .Java && !$0.useGameSpyQuery }
            print("[Migration v3] Found \(candidates.count) Java server(s) to probe for GameSpy support")
            
            for server in candidates {
                // Use SRV-resolved address if available, otherwise fall back to direct address
                let host = (!server.srvServerUrl.isEmpty) ? server.srvServerUrl : server.serverUrl
                let port = (server.srvServerPort > 1) ? server.srvServerPort : server.serverPort
                
                guard !host.isEmpty, port > 0 else {
                    print("[Migration v3] Skipping \(server.name) — missing host/port")
                    continue
                }
                
                let supported = await checkGameSpyWithTimeout(serverUrl: host, port: port)
                if supported {
                    server.useGameSpyQuery = true
                    print("[Migration v3] ✅ GameSpy enabled for '\(server.name)' (\(host):\(port))")
                } else {
                    print("[Migration v3] ❌ GameSpy not available for '\(server.name)' (\(host):\(port))")
                }
            }
            
            do {
                try context.save()
                print("[Migration v3] GameSpy auto-detection migration complete.")
            } catch {
                print("[Migration v3] Failed to save GameSpy migration results: \(error)")
            }
        }
    }
    
    /// Races a GameSpy4 query against a 2-second timeout.
    /// Returns true if the server responded to the GameSpy protocol, false otherwise.
    private static func checkGameSpyWithTimeout(serverUrl: String, port: Int) async -> Bool {
        do {
            return try await withThrowingTaskGroup(of: Bool.self) { group in
                // Task 1: attempt GameSpy query
                group.addTask {
                    let checker = GameSpy4StatusChecker(serverAddress: serverUrl, port: port)
                    _ = try await checker.checkServer()
                    return true
                }
                // Task 2: 2-second timeout sentinel
                group.addTask {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    return false
                }
                // Return whichever finishes first
                guard let result = try await group.next() else { return false }
                group.cancelAll()
                return result
            }
        } catch {
            // GameSpy query threw (unreachable, parse error, etc.) — not supported
            return false
        }
    }
}
