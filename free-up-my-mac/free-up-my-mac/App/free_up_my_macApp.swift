//
//  free_up_my_macApp.swift
//  free-up-my-mac
//
//  Created by Rounak Salim on 1/22/26.
//

import SwiftUI

@main
struct free_up_my_macApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 900, height: 700)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Scan") {
                    NotificationCenter.default.post(name: .newScan, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(replacing: .help) {
                Button("Free Up My Mac Help") {
                    // Open help documentation when available
                }
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newScan = Notification.Name("newScan")
}
