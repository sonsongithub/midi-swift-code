//
//  SendView.swift
//  VirtualSource
//
//  Created by Shinichiro Oba on 2022/10/14.
//

import SwiftUI

struct SendView: View {
    let action: (UInt8, Double?) -> Void
    
    @State var noteString = "60"
    @State var delayString = ""
    
    var body: some View {
        HStack {
            TextField("Note", text: $noteString)
            TextField("Delay (ms)", text: $delayString)
            Button("Send") {
                guard let note = UInt8(noteString) else { return }
                let delay = Double(delayString)
                action(note, delay)
            }
        }
    }
}

struct SendView_Previews: PreviewProvider {
    static var previews: some View {
        SendView { print($0, $1 ?? "nil") }
    }
}
