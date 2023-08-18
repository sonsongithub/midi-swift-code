import Foundation
import CoreMIDI

//
// CoreMIDI sample control for ZOOM MS-50G/60B/70CDR
//

import PlaygroundSupport

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
///   - block: A callback block the system invokes with incoming MIDI from sources connected to this port.
/// - Returns: MIDI client and MIDI port to receive MIDI message.
/// - Throws: NSError.
func initInput(clientName:String, portName: String, block: @escaping MIDIReceiveBlock) throws -> (MIDIClientRef, MIDIPortRef) {
    var client = MIDIClientRef()
    var port = MIDIPortRef()
    var result = OSStatus()
    
    result = MIDIClientCreate(clientName as CFString, nil, nil, &client)
    if result != noErr {
        throw NSError()
    }
    
    result = MIDIInputPortCreateWithProtocol(client, portName as CFString, ._2_0, &port, block)
    if result != noErr {
        throw NSError()
    }
    
    return (client, port)
}

enum MIDI2SystemExclusiveStatus {
    case one
    case start
    case `continue`
    case end
    
    var value: UInt32 {
        switch self {
        case .one:
            return 0
        case .start:
            return 1
        case .continue:
            return 2
        case .end:
            return 3
        }
    }
}

/// This function converts MIDI1.0 System Exclusive message to MIDI2.0 8-Byte UMP Formats.
/// MIDI2.0 messages are returned as UInt32 arrays.
/// Please refer to Universal MIDI Packet (UMP) Format and MIDI 2.0 Protocol
///
/// - Parameters:
///   - bytes: MIDI1.0 System Exclusive message as UInt8 array.
/// - Returns: MIDI2.0 messages are returned as UInt32 arrays.
/// - Throws: NSError.
func convertSysExMIDI1toMIDI2UMP8(bytes: [UInt8]) throws -> [UInt32] {
    var buf = bytes
    
    guard bytes.count > 0 else { throw NSError() }
    
    if bytes.count > 3 {
        // Remove status bytes from system exclusive if they are included in bytes.
        if buf[0] == UInt8(0xF0) {
            buf.remove(at: 0)
        }
        if buf[buf.count-1] == UInt8(0xF7) {
            buf.removeLast()
        }
    }

    var result: [UInt32] = []
    
    while buf.count > 0 {
        var status: MIDI2SystemExclusiveStatus = .continue
        if result.count == 0 && buf.count <= 6 {
            status = .one
        }
        if result.count == 0 && buf.count > 6 {
            status = .start
        }
        if result.count > 0 && buf.count <= 6 {
            status = .end
        }

        var length: UInt32 = buf.count > 6 ? 6 : UInt32(buf.count)

        var word0: UInt32 = UInt32(0x30) << 24 + (status.value << 20) + (UInt32(length) << 16)
        if buf.count > 0 {
            word0 = word0 + UInt32(buf[0]) << 8
            buf.remove(at: 0)
        }
        if buf.count > 0 {
            word0 = word0 + UInt32(buf[0])
            buf.remove(at: 0)
        }
        var word1: UInt32 = 0
        var counter: Int = 3
        while buf.count > 0 && counter >= 0 {
            word1 = word1 + UInt32(buf[0]) << (8 * counter)
            buf.remove(at: 0)
            counter-=1
        }
        result.append(word0)
        result.append(word1)
    }
    return result
}

do {
    let (destinationUniqueID, sourceUniqueID) = try getEndPointIDsThatHave()
    let (destination, _) = try getEndPoint(with: destinationUniqueID)
    let (source, _) = try getEndPoint(with: sourceUniqueID)
    let (_, sourcePort) = try initInput(clientName: "clientDest", portName: "portDest",block: { listPointer, context in
        let num = listPointer.pointee.numPackets
        for packet in listPointer.unsafeSequence() {
            print("word0=\(String(format: "%08X", packet.pointee.words.0))")
            print("word1=\(String(format: "%08X", packet.pointee.words.1))")
        }
    })
    MIDIPortConnectSource(sourcePort, source, nil)
    
    var outputPort = MIDIPortRef()
    var destinationClient = MIDIClientRef()
    var result = MIDIClientCreate("test" as CFString, nil, nil, &destinationClient)
    if result != noErr {
        throw NSError()
    }
    
    result = MIDIOutputPortCreate(destinationClient, "output" as CFString, &outputPort)
    if result != noErr {
        throw NSError()
    }

    do {
        let bytes : [UInt8] = [UInt8(0x7E), UInt8(0x00), UInt8(0x06), UInt8(0x01)]
        let ump = try convertSysExMIDI1toMIDI2UMP8(bytes: bytes)
        var eventList: MIDIEventList = .init()
        var packet = MIDIEventListInit(&eventList, ._2_0)
        MIDIEventListAdd(&eventList, 1024, packet, 0, ump.count, ump)
        MIDISendEventList(outputPort, destination, &eventList)
    }
    Thread.sleep(forTimeInterval: 1)

    do {
        // parameter edit mode
        // 0xf0,0x52,0x00,0x58,0x50,0xf7
        let bytes : [UInt8] = [UInt8(0x52), UInt8(0x00), UInt8(0x5f), UInt8(0x50)]
        let ump = try convertSysExMIDI1toMIDI2UMP8(bytes: bytes)
        var eventList: MIDIEventList = .init()
        var packet = MIDIEventListInit(&eventList, ._2_0)
        MIDIEventListAdd(&eventList, 1024, packet, 0, ump.count, ump)
        MIDISendEventList(outputPort, destination, &eventList)
    }
    Thread.sleep(forTimeInterval: 1)

    do {
        // request current patch
        // [0xf0,0x52,0x00,0x58,0x29,0xf7]
        let bytes : [UInt8] = [UInt8(0x52), UInt8(0x00), UInt8(0x5f), UInt8(0x29)]
        let ump = try convertSysExMIDI1toMIDI2UMP8(bytes: bytes)
        var eventList: MIDIEventList = .init()
        var packet = MIDIEventListInit(&eventList, ._2_0)
        MIDIEventListAdd(&eventList, 1024, packet, 0, ump.count, ump)
        MIDISendEventList(outputPort, destination, &eventList)
    }
} catch {
    print(error)
}
