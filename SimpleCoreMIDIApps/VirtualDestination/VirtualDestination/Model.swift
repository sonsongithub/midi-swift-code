//
//  Model.swift
//  VirtualDestination
//
//  Created by Shinichiro Oba on 2022/10/15.
//

import Foundation
import CoreMIDI

struct LogItem: Identifiable {
    let id = UUID()
    let date: Date
    let timeStamp: MIDITimeStamp
    let text: String
}

func eventListUMP8Byte2UInt8(list: UnsafePointer<MIDIEventList> ) -> [UInt8] {
    let tmp:[[UInt8]] = list.unsafeSequence().map { element -> [UInt8] in
        let mt = element.pointee.words.0 >> 28
        let group = (element.pointee.words.0 >> 24) & UInt32(0x0f)
        let status = (element.pointee.words.0 >> 20) & UInt32(0x0f)
        let length = (element.pointee.words.0 >> 16) & UInt32(0x0f)
        print("mt=\(mt)")
        print("group=\(group)")
        print("status=\(status)")
        print("length=\(length)")
        
        var uint8packets: [UInt8] = element.words().map({
            
            return [UInt8(($0 & 0xff000000) >> 24), UInt8(($0 & 0x00ff0000) >> 16), UInt8(($0 & 0x0000ff00) >> 8), UInt8(($0 & 0x000000ff) >> 0)]
        }).flatMap({$0})
        
        if uint8packets.count > 0 {
            uint8packets.remove(at: 0)
        }
        if uint8packets.count > 0 {
            uint8packets.remove(at: 0)
        }
        print(uint8packets)
        return Array(uint8packets[0..<Int(length)])
    }
    
    return tmp.flatMap({$0})
}

@MainActor
class Model: ObservableObject {
    @Published var logItems: [LogItem] = []
    
    private var clientRef = MIDIClientRef()
    
    private var destinationRef = MIDIEndpointRef()
    private var umpDestinationRef = MIDIEndpointRef()
    
    init() {
        var sourceUniqueID: Int32 = 0
        do {
            for i in 0..<MIDIGetNumberOfDevices() {
                do {
                    let dest = MIDIGetSource(i)
                    var name: Unmanaged<CFString>?
                    var result = MIDIObjectGetStringProperty(dest, kMIDIPropertyDisplayName, &name)
                    if result != noErr {
                    }
                    if let temp = name?.takeRetainedValue() as? String {
                        print(temp)
                        if temp == "VirtualSource - UMP MIDI 1.0" {
                            var tempInt32 = Int32(0)
                            result = MIDIObjectGetIntegerProperty(dest, kMIDIPropertyUniqueID, &tempInt32)
                            if result != noErr {
                                throw NSError(domain: "com.sonson.CoreMIDI", code: 1)
                            }
                            sourceUniqueID = tempInt32
                            break
                        }
                    }
                }
            }
            
            var endPoint = MIDIEndpointRef()
            var foundObjectType = MIDIObjectType.device
            var result = MIDIObjectFindByUniqueID(sourceUniqueID, &endPoint, &foundObjectType)
            if result != noErr {
                throw NSError()
            }
            
            let clientName = "clientName"
            let portName = "portName"
            var client = MIDIClientRef()
            var port = MIDIPortRef()
            result = OSStatus()
            
            result = MIDIClientCreate(clientName as CFString, nil, nil, &client)
            if result != noErr {
                throw NSError()
            }
            
            result = MIDIInputPortCreateWithProtocol(client, portName as CFString, ._1_0, &port, { eventList, pointer in
                let tmp = eventListUMP8Byte2UInt8(list: eventList)
                let buf = tmp.map({String(format: "%02x", $0)}).joined(separator: " ")
                print(buf)
            })
            if result != noErr {
                throw NSError()
            }
            
            MIDIPortConnectSource(port, endPoint, nil)
            
            
        } catch {
            print(error)
        }
        
        
//        MIDIClientCreate("VirtualDestination - Cient" as CFString, nil, nil, &clientRef)
//
//        MIDIDestinationCreateWithBlock(clientRef, "VirtualDestination - Deprecated API" as CFString, &destinationRef) { [weak self] pktList, srcConnRefCon in
//            for packet in pktList.unsafeSequence() {
//                let text = packet.bytes().map({ String(format: "%02x", $0) }).joined(separator: " ")
//                Task { @MainActor in
//                    self?.logItems.append(.init(date: Date(), timeStamp: packet.pointee.timeStamp, text: text))
//                }
//            }
//        }
//
//        MIDIDestinationCreateWithProtocol(clientRef, "VirtualDestination - UMP MIDI 1.0" as CFString, ._1_0, &umpDestinationRef) { [weak self]  evtlist, srcConnRefCon in
//            for packet in evtlist.unsafeSequence() {
//                let text = packet.words().map({ String(format: "%08x", $0) }).joined(separator: " ")
//                Task { @MainActor in
//                    self?.logItems.append(.init(date: Date(), timeStamp: packet.pointee.timeStamp, text: text))
//                }
//            }
//        }
    }
    
    deinit {
        MIDIEndpointDispose(destinationRef)
        MIDIEndpointDispose(umpDestinationRef)
    }
}
