//
//  ContentView.swift
//  VirtualSource
//
//  Created by Shinichiro Oba on 2022/10/14.
//

import SwiftUI

struct ContentView: View {
    @StateObject var model = Model()
    
    var body: some View {
        Form {
            Section("Deprecated API") {
                SendView { note, delay in
                    model.sendNoteOn(channel: 0, note: note, velocity: 100, delay: delay)
                }
            }
            Section("UMP MIDI 1.0") {
                SendView { note, delay in
                    model.sendMIDI1UPNoteOn(channel: 0, note: note, velocity: 100, delay: delay)
                }
            }
            
        }
        .padding()
        Button {
            model.sendSysEx()
        } label: {
            Text("send sysex")
        }

    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
