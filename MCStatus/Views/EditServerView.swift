//
//  EditServerView.swift
//  MC Status
//
//  Created by Tomer Shemesh on 8/13/23.
//

import SwiftUI
import SwiftData
import MCStatusDataLayer
import WidgetKit

enum GameSpyCheckState {
    case unknown, checking, supported, unsupported
}

struct EditServerView: View {
    
    private enum FocusedField {
        case serverName, serverAddress
    }
    
    @Environment(\.modelContext) private var modelContext

    @State var server: SavedMinecraftServer
    
    @Binding var isPresented: Bool
    var parentViewRefreshCallBack: () -> Void
    
    @FocusState private var focusedField: FocusedField?

    @State var tempNameInput = ""
    @State var tempServerInput = ""
    @State var tempPortInput: Int? = nil
    @State var tempServerType = ServerType.Java

    @State var portLabelPromptText = "Port (Optional - Default 25565)"

    @State private var showingInvalidURLAlert = false
    @State private var showingInvalidNameAlert = false
    @State private var showingInvalidPortAlert = false
    @State private var showingGameSpyUnavailableAlert = false

    // Tracks whether this server existed before the view opened (not a brand-new add)
    @State private var isExistingServer = false

    // Tracks the result of the GameSpy probe
    @State var gameSpyCheckState: GameSpyCheckState = .unknown

    // Temp toggle binding for the UI — used to intercept taps
    @State private var tempUseGameSpy = false

    var body: some View {
        Form {
            Section(header: Text("Start monitoring a server"), footer: Text("*MCStatus is used for checking the status an existing server. It will not create, setup, or host a new server.").padding(EdgeInsets(top: 10,leading: 0,bottom: 0,trailing: 0))) {
                HStack { Image(systemName: "list.bullet")
                        .foregroundColor(.gray)
                        .font(.headline)
                        .frame(width: 25, height: 25)
                    Picker("Server Type"
                           , selection: $tempServerType) {
                        Text("Java Edition").tag(ServerType.Java)
                        Text("Bedrock/MCPE").tag(ServerType.Bedrock)
                    }.onChange(of: tempServerType, initial: false) { oldValue, newValue in
                        if newValue == .Java {
                            portLabelPromptText = "Port (Optional - Default 25565)"
                        } else if newValue == .Bedrock {
                            portLabelPromptText = "Port (Optional - Default 19132)"
                        }
                    }

                }
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.gray)
                        .font(.headline)
                        .frame(width: 25, height: 25)
                    TextField("Server Name", text: $tempNameInput, prompt: Text("Server Name")).textInputAutocapitalization(.words).submitLabel(.next).focused($focusedField, equals: .serverName).onSubmit {
                        focusedField = .serverAddress
                    }
                }
                HStack {
                    Image(systemName: "rectangle.connected.to.line.below")
                        .foregroundColor(.gray)
                        .font(.headline)
                        .frame(width: 25, height: 25)
                    TextField("Server Address/IP", text: $tempServerInput, prompt: Text("Server Address/IP")).autocapitalization(.none).keyboardType(.URL).autocorrectionDisabled(true).submitLabel(.done).focused($focusedField, equals: .serverAddress)
                        .onChange(of: tempServerInput, initial: false) { oldValue, newValue  in
                            extractPort(from: newValue)
                        }
                }
                HStack {
                    Image(systemName: "number")
                        .foregroundColor(.gray)
                        .font(.headline)
                        .frame(width: 25, height: 25)
                    TextField(portLabelPromptText, value: $tempPortInput, formatter: NumberFormatter(), prompt: Text(portLabelPromptText)).keyboardType(.numberPad)
                }
            }.headerProminence(.increased)

            // GameSpy section — only visible for existing Java servers
            if isExistingServer && tempServerType == .Java {
                Section {
                    HStack {
                        if gameSpyCheckState == .checking {
                            Text("GameSpy Query")
                            Spacer()
                            ProgressView()
                        } else {
                            Toggle(isOn: $tempUseGameSpy) {
                                Text("GameSpy Query")
                            }
                            .onChange(of: tempUseGameSpy, initial: false) { oldValue, newValue in
                                if newValue && gameSpyCheckState != .supported {
                                    // User tapped to enable — run the probe
                                    runGameSpyProbe()
                                } else if !newValue && gameSpyCheckState == .supported {
                                    // User manually disabled
                                    gameSpyCheckState = .unknown
                                    server.useGameSpyQuery = false
                                    try? modelContext.save()
                                }
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Requires enable-query=true in server.properties. When enabled, shows the full player list beyond the 12-player preview.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
            .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isPresented = false
                } label: {
                    Text("Cancel")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saveItem()
                } label: {
                    Text("Save")
                }.disabled(saveDisabled())
            }
            
        }
            .onAppear {
            // Detect if this is an existing server (has a real URL) or a brand-new add
            isExistingServer = !server.serverUrl.isEmpty

            tempServerInput = server.serverUrl
            if (server.serverPort != 0) {
                tempPortInput = server.serverPort
            }
            tempNameInput = server.name
            tempServerType = server.serverType
            focusedField = .serverName

            // Restore GameSpy state based on persisted value
            if server.useGameSpyQuery {
                gameSpyCheckState = .supported
                tempUseGameSpy = true
            } else {
                gameSpyCheckState = .unknown
                tempUseGameSpy = false
            }
        }.interactiveDismissDisabled(inputHasChanged())
        
        .alert("Invalid Server URL/IP Address", isPresented: $showingInvalidURLAlert) {
            Button("OK") {
                
            }
        } message: {
            Text("Minecraft Server domains/ip addresses must be the root domain, and not contain any '/' or ':'")
        }
        .alert("Invalid Server Name", isPresented: $showingInvalidNameAlert) {
            Button("OK") {
                
            }
        } .alert("Invalid Port", isPresented: $showingInvalidPortAlert) {
            Button("OK") {
                
            }
        } message: {
            Text("Port must be a number between 0 and 65535")
        }
        .alert("GameSpy Unavailable", isPresented: $showingGameSpyUnavailableAlert) {
            Button("OK") { }
        } message: {
            Text("This server doesn't have the query protocol enabled. The server owner must set enable-query=true in server.properties.")
        }
    }
    //
    private func extractPort(from text: String) {
            // Check if the text contains a colon
            if let colonIndex = text.firstIndex(of: ":") {
                // Extract the port number after the colon
                let portValue = text[text.index(after: colonIndex)...]
                let port = String(portValue)
                // Remove the port from serverIP if necessary
                let serverIP = String(text[..<colonIndex])
                tempServerInput = serverIP
                tempPortInput = Int(port)
            }
        }
    
    
    private func saveDisabled() -> Bool {
        return tempNameInput.isEmpty || tempServerInput.isEmpty
    }
    
    private func inputHasChanged() -> Bool {
        tempNameInput != server.name ||
        tempServerInput != server.serverUrl ||
        (tempPortInput ?? 0) != server.serverPort
    }
    
    // server domains cannot have / or :
    private func isUrlValid(url: String) -> Bool {
        return !url.contains(":") && !url.contains("/")
    }

    // Runs the GameSpy probe against the current server config
    private func runGameSpyProbe() {
        gameSpyCheckState = .checking
        tempUseGameSpy = false // reset UI until we confirm

        Task {
            let url = server.serverUrl
            let port = server.serverPort
            do {
                // Probe GameSpy directly — only succeeds if the server actually supports it
                let checker = GameSpy4StatusChecker(serverAddress: url, port: port)
                _ = try await checker.checkServer()
                await MainActor.run {
                    server.useGameSpyQuery = true
                    gameSpyCheckState = .supported
                    tempUseGameSpy = true
                    try? modelContext.save()
                }
            } catch {
                await MainActor.run {
                    server.useGameSpyQuery = false
                    gameSpyCheckState = .unsupported
                    tempUseGameSpy = false
                    try? modelContext.save()
                    showingGameSpyUnavailableAlert = true
                }
            }
        }
    }
    
    // THIS IS CALLED WHEN A SERVER IS EDITED OR ADDED
    private func saveItem() {
        // first validate url doesnt contains any / or :
        tempServerInput = tempServerInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isUrlValid(url: tempServerInput) {
            showingInvalidURLAlert = true
            return
        }
        
        tempNameInput = tempNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if tempNameInput.isEmpty {
            showingInvalidNameAlert = true
            return
        }
        
        if let tempPortInput,tempPortInput < 0 || tempPortInput > 65535 {
            showingInvalidPortAlert = true
            return
        }
        
        // Capture whether this is an existing server BEFORE we update the model
        let wasExistingServer = isExistingServer
        
        withAnimation {
            server.serverUrl = tempServerInput
            if let tempPortInput {
                server.serverPort =  tempPortInput
            } else if tempServerType == .Java {
                server.serverPort = 25565
            } else if tempServerType == .Bedrock {
                server.serverPort = 19132
            }
            
            server.name = tempNameInput
            server.serverType = tempServerType
            server.srvServerUrl = ""
            server.srvServerPort = 0
            modelContext.insert(server)
            do {
                // Try to save
                try modelContext.save()
            } catch {
                // We couldn't save :(
                print(error.localizedDescription)
            }
            print("added server")
            MCStatusShortcutsProvider.updateAppShortcutParameters()
            parentViewRefreshCallBack()
            // force the widgets to refresh
            WidgetCenter.shared.reloadAllTimelines()
        }

        // After save: probe GameSpy only for NEW Java servers (first-time add)
        // Editing an existing server never auto-probes — user controls the toggle themselves
        if !wasExistingServer && tempServerType == .Java {
            gameSpyCheckState = .checking
            isExistingServer = true // make section visible so spinner shows

            Task {
                let url = server.serverUrl
                let port = server.serverPort
                do {
                    let checker = GameSpy4StatusChecker(serverAddress: url, port: port)
                    _ = try await checker.checkServer()
                    await MainActor.run {
                        server.useGameSpyQuery = true
                        gameSpyCheckState = .supported
                        tempUseGameSpy = true
                        try? modelContext.save()
                        isPresented = false
                    }
                } catch {
                    await MainActor.run {
                        server.useGameSpyQuery = false
                        gameSpyCheckState = .unsupported
                        tempUseGameSpy = false
                        try? modelContext.save()
                        isPresented = false
                    }
                }
            }
        } else {
            // Existing server edit — just close, toggle state already saved above
            isPresented = false
        }
    }

}



//#Preview {
//    EditServerView(server: )
//}
