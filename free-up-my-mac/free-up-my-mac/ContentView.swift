//
//  ContentView.swift
//  free-up-my-mac
//
//  Created by Rounak Salim on 1/22/26.
//

import SwiftUI

/// Root view with state-driven navigation between app screens
struct ContentView: View {
    @State private var viewModel = ScanViewModel()
    @State private var showingHistory = false

    var body: some View {
        Group {
            switch viewModel.appState {
            case .idle:
                MainView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))

            case .scanning:
                ScanProgressView(viewModel: viewModel)
                    .transition(.opacity)

            case .results:
                ResultsView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))

            case .error(let message):
                ErrorView(message: message, viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.appState)
        .frame(minWidth: 800, minHeight: 600)
        .sheet(isPresented: $showingHistory) {
            HistoryView()
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showingHistory = true
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .help("View cleanup history")
            }
        }
    }
}

#Preview {
    ContentView()
}
