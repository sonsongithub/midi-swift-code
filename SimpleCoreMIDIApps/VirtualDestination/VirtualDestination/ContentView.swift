//
//  ContentView.swift
//  VirtualDestination
//
//  Created by Shinichiro Oba on 2022/10/15.
//

import SwiftUI

struct ContentView: View {
    @StateObject var model = Model()
    
    var body: some View {
        List {
            ForEach(model.logItems) { logItem in
                HStack {
                    Text(logItem.date.description)
                    Text(String(logItem.timeStamp))
                    Text(logItem.text)
                }
                .font(.body.monospacedDigit())
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
