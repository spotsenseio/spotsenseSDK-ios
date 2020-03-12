// Copyright 2015-2016 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import CoreBluetooth

///
/// BeaconID
///
/// Uniquely identifies an Eddystone compliant beacon.
///
public class BeaconID : NSObject {

 public enum BeaconType {
    case Eddystone              // 10 bytes namespace + 6 bytes instance = 16 byte ID
    case EddystoneEID           // 8 byte ID
  }

 public let beaconType: BeaconType

  ///
  /// The raw beaconID data. This is typically printed out in hex format.
  ///
    internal let beaconID: [UInt8]

public init(beaconType: BeaconType!, beaconID: [UInt8]) {
    self.beaconID = beaconID
    self.beaconType = beaconType
  }

    override public var description: String {
    if self.beaconType == BeaconType.Eddystone || self.beaconType == BeaconType.EddystoneEID {
      let hexid = hexBeaconID(beaconID: self.beaconID)
      return "\(hexid)"
    } else {
      return "BeaconID with invalid type (\(beaconType))"
    }
  }

  public func hexBeaconID(beaconID: [UInt8]) -> String {
    var retval = ""
    for byte in beaconID {
      var s = String(byte, radix:16, uppercase: false)
      if s.count == 1 {
        s = "0" + s
      }
      retval += s
    }
    return retval
  }

}

func ==(lhs: BeaconID, rhs: BeaconID) -> Bool {
  if lhs == rhs {
    return true;
  } else if lhs.beaconType == rhs.beaconType
    && rhs.beaconID == rhs.beaconID {
      return true;
  }

  return false;
}

///
/// BeaconInfo
///
/// Contains information fully describing a beacon, including its beaconID, transmission power,
/// RSSI, and possibly telemetry information.
///


