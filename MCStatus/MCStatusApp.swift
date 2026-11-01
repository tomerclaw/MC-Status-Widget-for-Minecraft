//
//  MCStatusApp.swift
//  MCStatus
//
//  Created by Tomer Shemesh on 6/27/23.
//

import SwiftUI
import SwiftData
import MCStatusDataLayer
import AppIntents

@main
struct MCStatusApp: App {
    @StateObject private var watchHelper = WatchHelper()
    
    init() {
        print("Main App Init")
    }
    var body: some Scene {
        WindowGroup {
            MainAppContentView()
                .environmentObject(watchHelper)
        }
        .modelContainer(SwiftDataHelper.getModelContainter())
    }
}
