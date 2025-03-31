//
//  ContentView.swift
//  HTTPDemo
//
//  Created by supertext on 2025/3/31.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 25) {
                Button("Model GET") {
                    let req:ModelRequest<GoogleOidcConfig> = "https://accounts.google.com/.well-known/openid-configuration"
                    net.request(req).then { config in
                        await processConfig(config)
                    }.catch { err in
                        print(err)
                    }
                }
                Button("Simple GET") {
                    net.request(ConfigRequest()).then { config in
                        await processConfig(config)
                    }.catch { err in
                        print(err)
                    }
                }
            }
        }
    }
    func processConfig(_ config:GoogleOidcConfig){
        print(config)
    }
}
#Preview {
    ContentView()
}
