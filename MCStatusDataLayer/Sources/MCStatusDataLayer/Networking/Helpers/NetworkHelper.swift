//
//  NetworkHelper.swift
//  MCStatusDataLayer
//
//  Created by Tomer Shemesh on 12/4/25.
//

import dnssd

class NetworkHelper {

    // Checks if the given string is an ip address.
    static func isIpAddress(ipToValidate: String) -> Bool {
        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()

        if ipToValidate.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
            // IPv6 peer.
            return true
        } else if ipToValidate.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1 {
            // IPv4 peer.
            return true
        }

        return false;
    }

    // Checks if the given string is a private IPv4 address
    // 10.0.0.0 – 10.255.255.255
    // 172.16.0.0 – 172.31.255.255
    // 192.168.0.0 – 192.168.255.255
    // 127.0.0.0 – 127.255.255.255 (loopback)
    // 169.254.0.0 – 169.254.255.255 (link-local)
    static func isPrivateIPv4(host: String) -> Bool {
        let parts = host.split(separator: ".")
        guard parts.count == 4 else { return false }
        let nums = parts.compactMap { Int($0) }
        guard nums.count == 4, nums.allSatisfy({ 0...255 ~= $0 }) else { return false }

        let a = nums[0], b = nums[1]

        if a == 10 { return true }
        if a == 127 { return true }                    // loopback
        if a == 169 && b == 254 { return true }        // link-local
        if a == 192 && b == 168 { return true }
        if a == 172 && (16...31).contains(b) { return true }

        return false
    }
}
