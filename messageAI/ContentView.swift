//
//  ContentView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Root content view of the app
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        AuthContainerView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
