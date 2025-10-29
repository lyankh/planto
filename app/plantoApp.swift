//
//  plantoApp.swift
//  planto
//
//  Created by Lyan on 29/04/1447 AH.
//

import SwiftUI
import UserNotifications

@main
struct plantoApp: App {
    init() {
        NotificationManager.shared.requestAuthorization()
    }
    var body: some Scene {
        WindowGroup {
            ContentView() 
                .preferredColorScheme(.dark)
        }
    }
}
