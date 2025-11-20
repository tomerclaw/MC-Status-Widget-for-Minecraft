//
//  ServerStatusCheckerProtocol.swift
//  MCStatus
//
//  Created by Tomer Shemesh on 7/29/23.
//

import Foundation

public protocol ServerStatusCheckerProtocol {
    init(serverAddress: String, port: Int)
    
    func checkServer() async throws -> Data
    func getParser() -> ServerStatusParserProtocol.Type
}


public protocol ServerStatusParserProtocol {
    static func parseServerResponse(input: Data, config: ServerCheckerConfig?) throws -> ServerStatus
}


public enum ServerStatusCheckerError: Error {
    case DeviceNotConnected
    case ServerUnreachable
    case StatusUnparsable
    case InvalidPort
    case QueryBlocked
}



