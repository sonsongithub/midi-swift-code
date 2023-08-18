import Foundation
import CoreMIDI

import PlaygroundSupport

//
// CoreMIDI sample control for ZOOM MS-50G/60B/70CDR
// Using deprecated APIs
//

PlaygroundPage.current.needsIndefiniteExecution = true

/// Get source and destination devices that have the specified name.
/// If there are no source and destination devices that have the specified name and some errors are happened, this function throws error.
///
/// - Parameter deviceName: MIDI device name.
/// - Returns: Unique ID of source and destination devices.
/// - Throws: NSError.
func getEndPointIDsThatHave(deviceName: String = "ZOOM MS Series") throws -> (Int32, Int32) {
    var destinationUniqueID: Int32?
    var sourceUniqueID: Int32?
    var result = noErr

    for i in 0..<MIDIGetNumberOfDevices() {
        do {
            let endPoint = MIDIGetDestination(i)
            var name: Unmanaged<CFString>?
            result = MIDIObjectGetStringProperty(endPoint, kMIDIPropertyDisplayName, &name)
            if result != noErr {
                throw NSError(domain: "com.sonson.CoreMIDI", code: 0)
            }
            if let temp = name?.takeRetainedValue() as? String {
                if temp == deviceName {
                    var tempInt32 = Int32(0)
                    result = MIDIObjectGetIntegerProperty(endPoint, kMIDIPropertyUniqueID, &tempInt32)
                    if result != noErr {
                        throw NSError(domain: "com.sonson.CoreMIDI", code: 1)
                    }
                    destinationUniqueID = tempInt32
                    break
                }
            }
        }
    }
    for i in 0..<MIDIGetNumberOfDevices() {
        do {
            let dest = MIDIGetSource(i)
            var name: Unmanaged<CFString>?
            result = MIDIObjectGetStringProperty(dest, kMIDIPropertyDisplayName, &name)
            if result != noErr {
                throw NSError(domain: "com.sonson.CoreMIDI", code: 0)
            }
            if let temp = name?.takeRetainedValue() as? String {
                if temp == deviceName {
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
    if let t1 = destinationUniqueID, let t2 = sourceUniqueID {
        return (t1, t2)
    }
    throw NSError(domain: "com.sonson.CoreMIDI", code: 2)
}

/// Get MIDIEndPointRef and MIDIObjectType from unique ID.
///
/// - Parameter uniqueID:
/// - Returns: MIDI end point and type of the MIDI end point.
/// - Throws: NSError.
func getEndPoint(with uniqueID: Int32) throws -> (MIDIEndpointRef, MIDIObjectType) {
    var endPoint = MIDIEndpointRef()
    var foundObjectType = MIDIObjectType.device
    var result = MIDIObjectFindByUniqueID(uniqueID, &endPoint, &foundObjectType)
    if result != noErr {
        throw NSError()
    }
    return (endPoint, foundObjectType)
}

/// Get MIDIClientRef and MIDIPortRef that can receive MIDI message.
///
/// - Parameters:
///   - clientName: The name of MIDI client.
///   - portName: The name of MIDI port.
///   - block: The MIDIReadBlock which will be called with incoming MIDI, from sources connected to this port.
/// - Returns: MIDI client and MIDI port to receive MIDI message.
/// - Throws: NSError.
func initInput(clientName:String, portName: String, block: @escaping MIDIReadBlock) throws -> (MIDIClientRef, MIDIPortRef) {
    var client = MIDIClientRef()
    var port = MIDIPortRef()
    var result = OSStatus()
    
    result = MIDIClientCreate(clientName as CFString, nil, nil, &client)
    if result != noErr {
        throw NSError()
    }
    result = MIDIInputPortCreateWithBlock(client, portName as CFString, &port, block)
    if result != noErr {
        throw NSError()
    }
    
    return (client, port)
}

do {
    let (destinationUniqueID, sourceUniqueID) = try getEndPointIDsThatHave()
    let (destination, _) = try getEndPoint(with: destinationUniqueID)
    let (source, _) = try getEndPoint(with: sourceUniqueID)
    let (sourceClient, sourcePort) = try initInput(clientName: "clientDest", portName: "portDest", block: {pointer, raw in

        print("--------")
        for packet in pointer.unsafeSequence() {
            let text = packet.bytes().map({ String(format: "%02X", $0) }).joined(separator: " ")
            print(text)
        }
    })
    
    var outputClient = MIDIClientRef()
    var outputPort = MIDIPortRef()
    var result = MIDIClientCreate("test" as CFString, nil, nil, &outputClient)
    MIDIOutputPortCreate(outputClient, "output" as CFString, &outputPort)
    MIDIPortConnectSource(sourcePort, source, nil)

    do {
        // Identity Request
        // [0xf0,0x7e,0x00,0x06,0x01,0xf7]
        var pkt = UnsafeMutablePointer<MIDIPacket>.allocate(capacity: 1)
        var pktList = UnsafeMutablePointer<MIDIPacketList>.allocate(capacity: 1)
        let midiData : [UInt8] = [UInt8(0xF0), UInt8(0x7E), UInt8(0x00), UInt8(0x06), UInt8(0x01), UInt8(0xF7)]
        pkt = MIDIPacketListInit(pktList)
        pkt = MIDIPacketListAdd(pktList, 1024, pkt, 0, 6, midiData)
        MIDISend(outputPort, destination, pktList)
    }
    Thread.sleep(forTimeInterval: 1.0)
    
    do {
        // Parameter Edit Enable
        // MS-60B
        // [0xf0,0x52,0x00,0x5f,0x50,0xf7]
        var pkt = UnsafeMutablePointer<MIDIPacket>.allocate(capacity: 1)
        var pktList = UnsafeMutablePointer<MIDIPacketList>.allocate(capacity: 1)
        let midiData : [UInt8] = [UInt8(0xF0), UInt8(0x52), UInt8(0x00), UInt8(0x5f), UInt8(0x50), UInt8(0xF7)]
        pkt = MIDIPacketListInit(pktList)
        pkt = MIDIPacketListAdd(pktList, 1024, pkt, 0, 6, midiData)
        MIDISend(outputPort, destination, pktList)
    }
    Thread.sleep(forTimeInterval: 1.0)
    
    do {
        // Request current patch data
        // MS-60B
        // [0xf0,0x52,0x00,0x58,0x29,0xf7]
        var pkt = UnsafeMutablePointer<MIDIPacket>.allocate(capacity: 1)
        var pktList = UnsafeMutablePointer<MIDIPacketList>.allocate(capacity: 1)
        let midiData : [UInt8] = [UInt8(0xF0), UInt8(0x52), UInt8(0x00), UInt8(0x5f), UInt8(0x29), UInt8(0xF7)]
        pkt = MIDIPacketListInit(pktList)
        pkt = MIDIPacketListAdd(pktList, 1024, pkt, 0, 6, midiData)
        MIDISend(outputPort, destination, pktList)
    }
} catch {
    print(error)
}
