//
//  GameSpy4StatusChecker.swift
//  MCStatusDataLayer
//
//  Created by Tomer Shemesh on 11/20/25.
//

import Foundation
import Network

public class GameSpy4StatusChecker: ServerStatusCheckerProtocol {
    let serverAddress: String
    let port: Int
    
    var continuation: CheckedContinuation<Data, Error>?
    var continuationHasBeenCalled = false
    let continuationQueue = DispatchQueue(label: "continuationCallerQueue")
    let queue = DispatchQueue(label: "continuationCallerQueue")
    var udpClient: UDPClient?
    
    enum QueryStep {
        case challenge
        case query
    }

    var currentStep: QueryStep = .challenge
    
    func callContinuationResume(result: Data) {
        queue.sync {
            guard !continuationHasBeenCalled else {
                return
            }
            continuationHasBeenCalled = true
            continuation?.resume(returning: result)
        }
    }
    
    func callContinuationError(error: ServerStatusCheckerError) {
        queue.sync {
            guard !continuationHasBeenCalled else {
                return
            }
            continuationHasBeenCalled = true
            continuation?.resume(throwing: error)
        }
    }
    
    
    public required init(serverAddress: String, port: Int) {
        self.serverAddress = serverAddress
        self.port = port
    }
    
    public func checkServer() async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.startConnection()
        }
    }
    
    public func getParser() -> ServerStatusParserProtocol.Type {
        return GameSpy4StatusParser.self
    }
    
    
    func startConnection() {
        udpClient = UDPClient(
            address: self.serverAddress,
            port: Int32(self.port),
            listener: { responseType, udpClient, data in
                guard responseType == .SUCCESS, let data = data else {
                    self.callContinuationError(error: .ServerUnreachable)
                    return
                }
                
                switch self.currentStep {
                case .challenge:
                    // Parse challenge response
                    if let challengeValue = self.parseChallenge(data) {
                        self.currentStep = .query
                        let challengePacked = self.packChallenge(challengeValue)
                        let statPacket = self.buildStatisticPacket(challengeData: challengePacked)
                        
                        // Send statistic query packet with challenge
                        udpClient?.send(statPacket)
                    }
                    
                case .query:
                    // Received query response from server
                    udpClient?.connection.cancel()
                    self.callContinuationResume(result: data)
                }
            },
            readyListener: { client in
                print("Connection ready, sending challenge packet...")
                self.currentStep = .challenge
                client.send(self.getChallengePacket())
            }
        )
    }
    
    // Data formats pulled from https://github.com/xPaw/PHP-Minecraft-Query/blob/master/src/MinecraftQuery.php
    
    // MARK: - GameSpy4 Protocol Methods
    // Challenge Packet: 0xFE 0xFD 0x09 <session id (4 bytes)>
    func getChallengePacket() -> Data {
        return Data([0xFE, 0xFD, 0x09, 0x01, 0x02, 0x03, 0x04]);
    }
    
    // Parse challenge response to extract challenge number
    // Response format: byte 0 = 0x09 (type), bytes 1–4 = session ID, bytes 5+ = null-terminated ASCII challenge integer
    func parseChallenge(_ data: Data) -> UInt32? {
        guard data.count > 5 else { return nil }
        let payload = data.dropFirst(5)
        if let str = String(data: payload, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0")) {
            return UInt32(str)
        }
        return nil
    }
    
    // Pack challenge number into 4-byte big-endian format
    func packChallenge(_ challenge: UInt32) -> Data {
        var value = challenge.bigEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
    
    // Build statistic query packet with challenge data
    func buildStatisticPacket(challengeData: Data) -> Data {
        var packet = Data([0xFE, 0xFD, 0x00, 0x01, 0x02, 0x03, 0x04]) // STATISTIC command = 0x00
        packet.append(challengeData)
        packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // padding
        return packet
    }
}
