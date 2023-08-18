//
//  Model.swift
//  VirtualSource
//
//  Created by Shinichiro Oba on 2022/10/14.
//

import Foundation
import CoreMIDI

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

@MainActor
class Model: ObservableObject {
    
    private var clientRef = MIDIClientRef()
    
    private var sourceRef = MIDIEndpointRef()
    private var umpSourceRef = MIDIEndpointRef()
    
    private let timebase: mach_timebase_info = {
        var timebase = mach_timebase_info()
        mach_timebase_info(&timebase)
        return timebase
    }()
    
    init() {
        MIDIClientCreate("VirtualSource - Cient" as CFString, nil, nil, &clientRef)
        
        MIDISourceCreate(clientRef, "VirtualSource - Deprecated API" as CFString, &sourceRef)
        MIDISourceCreateWithProtocol(clientRef, "VirtualSource - UMP MIDI 1.0" as CFString, ._1_0, &umpSourceRef)
    }
    
    deinit {
        MIDIEndpointDispose(sourceRef)
        MIDIEndpointDispose(umpSourceRef)
    }
    
    func sendNoteOn(channel: UInt8, note: UInt8, velocity: UInt8, delay: Double? = nil) {
        var packet = MIDIPacket()
        
        packet.length = 3
        packet.data.0 = 0x90 + (channel & 0x0f)
        packet.data.1 = note & 0x7f
        packet.data.2 = velocity & 0x7f
        
        if let delay {
            // Convert millisecond to MIDITimeStamp
            let delayTime = MIDITimeStamp(delay * 1_000_000 * Double(timebase.denom) / Double(timebase.numer))
            packet.timeStamp = mach_absolute_time() + delayTime
        }
        
        var packetList = MIDIPacketList(numPackets: 1, packet: packet)
        
        MIDIReceived(sourceRef, &packetList)
    }
    
    func sendMIDI1UPNoteOn(channel: UInt8, note: UInt8, velocity: UInt8, delay: Double? = nil) {
        var packet = MIDIEventPacket()
        
        packet.wordCount = 1
        packet.words.0 = MIDI1UPNoteOn(0, channel, note, velocity)
        
        print(String(format: "%08x", packet.words.0))
        
        if let delay {
            // Convert millisecond to MIDITimeStamp
            let delayTime = MIDITimeStamp(delay * 1_000_000 * Double(timebase.denom) / Double(timebase.numer))
            packet.timeStamp = mach_absolute_time() + delayTime
        }
        
        var eventList = MIDIEventList(protocol: ._1_0, numPackets: 1, packet: packet)
        
        MIDIReceivedEventList(umpSourceRef, &eventList)
    }
    
    func sendSysEx() {
        let messages: [UInt8] = [10, 10, 10, 10, 10, 10]
        do {
            let ump = try convertSysExMIDI1toMIDI2UMP8(bytes: messages)
            var eventList: MIDIEventList = .init()
            var packet = MIDIEventListInit(&eventList, ._2_0)
            MIDIEventListAdd(&eventList, 1024, packet, 0, ump.count, ump)
            MIDIReceivedEventList(umpSourceRef, &eventList)
        } catch {
            print(error)
        }
        
    }
}
