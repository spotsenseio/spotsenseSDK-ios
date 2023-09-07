//
//  BeaconInfo.swift
//  SpotSenseSDK
//
//  Created by Vibhor Jain on 06/09/23.
//  Copyright © 2023 SpotSense. All rights reserved.
//

import Foundation
import CoreBluetooth

public class BeaconInfo : NSObject {

  static let EddystoneUIDFrameTypeID: UInt8 = 0x00
  static let EddystoneURLFrameTypeID: UInt8 = 0x10
  static let EddystoneTLMFrameTypeID: UInt8 = 0x20
  static let EddystoneEIDFrameTypeID: UInt8 = 0x30
    
 public enum EddystoneFrameType {
    case UnknownFrameType
    case UIDFrameType
    case URLFrameType
    case TelemetryFrameType
    case EIDFrameType

    var description: String {
      switch self {
      case .UnknownFrameType:
        return "Unknown Frame Type"
      case .UIDFrameType:
        return "UID Frame"
      case .URLFrameType:
        return "URL Frame"
      case .TelemetryFrameType:
        return "TLM Frame"
      case .EIDFrameType:
        return "EID Frame"
      }
    }
  }

 public let beaconID: BeaconID
  let txPower: Int
  let RSSI: Int
  let telemetry: NSData?

  public init(beaconID: BeaconID, txPower: Int, RSSI: Int, telemetry: NSData?) {
    self.beaconID = beaconID
    self.txPower = txPower
    self.RSSI = RSSI
    self.telemetry = telemetry
  }

public class func frameTypeForFrame(advertisementFrameList: [NSObject : AnyObject]) -> EddystoneFrameType {
      let uuid = CBUUID(string: "FEAA")
      if let frameData = advertisementFrameList[uuid] as? NSData {
        if frameData.length > 1 {
          let count = frameData.length
          var frameBytes = [UInt8](repeating: 0, count: count)
          frameData.getBytes(&frameBytes, length: count)

          if frameBytes[0] == EddystoneUIDFrameTypeID {
            return EddystoneFrameType.UIDFrameType
          } else if frameBytes[0] == EddystoneTLMFrameTypeID {
            return EddystoneFrameType.TelemetryFrameType
          } else if frameBytes[0] == EddystoneEIDFrameTypeID {
            return EddystoneFrameType.EIDFrameType
          } else if frameBytes[0] == EddystoneURLFrameTypeID {
            return EddystoneFrameType.URLFrameType
          }
        }
    }

     return EddystoneFrameType.UnknownFrameType
  }

 public class func telemetryDataForFrame(advertisementFrameList: [NSObject : AnyObject]!) -> NSData? {
    return advertisementFrameList[CBUUID(string: "FEAA")] as? NSData
  }

  ///
  /// Unfortunately, this can't be a failable convenience initialiser just yet because of a "bug"
  /// in the Swift compiler — it can't tear-down partially initialised objects, so we'll have to
  /// wait until this gets fixed. For now, class method will do.
  ///
 public class func beaconInfoForUIDFrameData(frameData: NSData, telemetry: NSData?, RSSI: Int) -> BeaconInfo? {
      if frameData.length > 1 {
        let count = frameData.length
        var frameBytes = [UInt8](repeating: 0, count: count)
        frameData.getBytes(&frameBytes, length: count)

        if frameBytes[0] != EddystoneUIDFrameTypeID {
          NSLog("Unexpected non UID Frame passed to BeaconInfoForUIDFrameData.")
          return nil
        } else if frameBytes.count < 18 {
          NSLog("Frame Data for UID Frame unexpectedly truncated in BeaconInfoForUIDFrameData.")
        }

        let txPower = Int(Int8(bitPattern:frameBytes[1]))
        let beaconID: [UInt8] = Array(frameBytes[2..<18])
        let bid = BeaconID(beaconType: BeaconID.BeaconType.Eddystone, beaconID: beaconID)
        return BeaconInfo(beaconID: bid, txPower: txPower, RSSI: RSSI, telemetry: telemetry)
      }

      return nil
  }

 public class func beaconInfoForEIDFrameData(frameData: NSData, telemetry: NSData?, RSSI: Int) -> BeaconInfo? {
      if frameData.length > 1 {
        let count = frameData.length
        var frameBytes = [UInt8](repeating: 0, count: count)
        frameData.getBytes(&frameBytes, length: count)

        if frameBytes[0] != EddystoneEIDFrameTypeID {
          NSLog("Unexpected non EID Frame passed to BeaconInfoForEIDFrameData.")
          return nil
        } else if frameBytes.count < 10 {
          NSLog("Frame Data for EID Frame unexpectedly truncated in BeaconInfoForEIDFrameData.")
        }

        let txPower = Int(Int8(bitPattern:frameBytes[1]))
        let beaconID: [UInt8] = Array(frameBytes[2..<10])
        let bid = BeaconID(beaconType: BeaconID.BeaconType.EddystoneEID, beaconID: beaconID)
        return BeaconInfo(beaconID: bid, txPower: txPower, RSSI: RSSI, telemetry: telemetry)
      }

      return nil
  }

public  class func parseURLFromFrame(frameData: NSData) -> NSURL? {
    if frameData.length > 0 {
      let count = frameData.length
      var frameBytes = [UInt8](repeating: 0, count: count)
      frameData.getBytes(&frameBytes, length: count)

      if let URLPrefix = URLPrefixFromByte(schemeID: frameBytes[2]) {
        var output = URLPrefix
        for i in 3..<frameBytes.count {
          if let encoded = encodedStringFromByte(charVal: frameBytes[i]) {
            output.append(encoded)
          }
        }

        return NSURL(string: output)
      }
    }

    return nil
  }

    override open var description: String {
    switch self.beaconID.beaconType {
    case .Eddystone:
      return "Eddystone \(self.beaconID), txPower: \(self.txPower), RSSI: \(self.RSSI)"
    case .EddystoneEID:
      return "Eddystone EID \(self.beaconID), txPower: \(self.txPower), RSSI: \(self.RSSI)"
    }
  }

public  class func URLPrefixFromByte(schemeID: UInt8) -> String? {
    switch schemeID {
    case 0x00:
      return "http://www."
    case 0x01:
      return "https://www."
    case 0x02:
      return "http://"
    case 0x03:
      return "https://"
    default:
      return nil
    }
  }

public  class func encodedStringFromByte(charVal: UInt8) -> String? {
    switch charVal {
    case 0x00:
      return ".com/"
    case 0x01:
      return ".org/"
    case 0x02:
      return ".edu/"
    case 0x03:
      return ".net/"
    case 0x04:
      return ".info/"
    case 0x05:
      return ".biz/"
    case 0x06:
      return ".gov/"
    case 0x07:
      return ".com"
    case 0x08:
      return ".org"
    case 0x09:
      return ".edu"
    case 0x0a:
      return ".net"
    case 0x0b:
      return ".info"
    case 0x0c:
      return ".biz"
    case 0x0d:
      return ".gov"
    default:
      return String(data: Data(bytes: [ charVal ] as [UInt8], count: 1), encoding: .utf8)
    }
  }

}
