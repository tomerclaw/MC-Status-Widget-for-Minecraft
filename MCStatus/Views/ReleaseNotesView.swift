//
//  ReleaseNotesView.swift
//  MCStatus
//
//  Created by Tomer Shemesh on 10/17/24.
//


import SwiftUI

// Feature model to hold title, description, icon, and icon color
struct Feature: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
}

struct ReleaseNotesView: View {
    @Environment(\.dismiss) var dismiss // Allows dismissing the sheet when done
    @Environment(\.openURL) private var openURL

    @State private var showingTipSheet = false
    var showDismissButton = true
    
    // Accept an array of features
    let features = [
        Feature(title: "GameSpy Query Support", description: "Java servers with the query protocol enabled now show the full player list on the server detail page — no more 12-player cap. Enable it per-server in server settings.", icon: "person.3.fill", iconColor: .green),
        Feature(title: "More Coming Soon!", description: "Stay tuned for more exciting features in upcoming releases!", icon: "sparkles", iconColor: .yellow)
    ]

    var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    Text("MC Status 2.1 adds **GameSpy Query support** for Java servers, unlocking the full player list for servers that have the query protocol enabled.")
                        .font(.body)
                        .padding(.bottom, 20)
                        .padding(.top,15)
                    
                    // Loop through each feature and display it dynamically
                    ForEach(features) { feature in
                        FeatureRow(feature: feature)
                    }
                    
                    // Thank You & Tip/Review Buttons Section
                    Divider()
                        .padding(.vertical, 5)

                    VStack(alignment: .center) {
                        Text("Thank you for your support!")
                            .font(.headline)
                            .padding(.bottom, 10)
                        
                        Text("If you love the app, consider leaving a review or leaving a small tip to help support development!")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 20)
                        
                        HStack(spacing: 10) {
                            Button(action: {
                                leaveAppReview()
                            }) {
                                Label("Leave a Review", systemImage: "star.fill")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .font(.callout)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                
                            }
                            
                            Button(action: {
                                showingTipSheet = true
                            }) {
                                Label("Leave a Tip", systemImage: "gift.fill")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .font(.callout)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)

                            }
                        }.padding(.bottom, 20).frame(maxWidth: .infinity)

                    }
                    
                }
                .padding([.leading, .trailing, .bottom], 30)
            }
            .navigationTitle("MC Status 2.1")
            .toolbar {
                if showDismissButton {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Got it!") {
                            dismiss() // Close the sheet when the user is done
                        }
                    }
                }
            }.sheet(isPresented: $showingTipSheet) {
                NavigationStack {
                    TipJarView(isPresented: $showingTipSheet)
                }
            }
    }
    
    
    func leaveAppReview() {
        // Replace the placeholder value below with the App Store ID for your app.
        // You can find the App Store ID in your app's product URL.
        let url = "https://apps.apple.com/app/id1408215245?action=write-review"
        guard let writeReviewURL = URL(string: url) else {
            print("Expected a valid URL")
            return
        }
        openURL(writeReviewURL)
    }
}

// View for individual feature row
struct FeatureRow: View {
    let feature: Feature
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: feature.icon)
                .foregroundColor(feature.iconColor)
                .imageScale(.large)
                .scaledToFit()
                .frame(width: 25,height: 25)
            VStack(alignment: .leading) {
                Text(feature.title)
                    .font(.headline)
                    .bold()
                Text(feature.description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}
