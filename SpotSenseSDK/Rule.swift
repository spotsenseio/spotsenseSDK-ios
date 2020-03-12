/*
 
   ______                         __       ______
  /      \                       /  |     /      \
 /$$$$$$  |  ______    ______   _$$ |_   /$$$$$$  |  ______   _______    _______   ______
 $$ \__$$/  /      \  /      \ / $$   |  $$ \__$$/  /      \ /       \  /       | /      \
 $$      \ /$$$$$$  |/$$$$$$  |$$$$$$/   $$      \ /$$$$$$  |$$$$$$$  |/$$$$$$$/ /$$$$$$  |
  $$$$$$  |$$ |  $$ |$$ |  $$ |  $$ | __  $$$$$$  |$$    $$ |$$ |  $$ |$$      \ $$    $$ |
 /  \__$$ |$$ |__$$ |$$ \__$$ |  $$ |/  |/  \__$$ |$$$$$$$$/ $$ |  $$ | $$$$$$  |$$$$$$$$/
 $$    $$/ $$    $$/ $$    $$/   $$  $$/ $$    $$/ $$       |$$ |  $$ |/     $$/ $$       |
  $$$$$$/  $$$$$$$/   $$$$$$/     $$$$/   $$$$$$/   $$$$$$$/ $$/   $$/ $$$$$$$/   $$$$$$$/
           $$ |
           $$ |
           $$/
 
 */


//
//  Rule.Swift
//  SpotSense Playground - Beta
//
//  Copyright © 2018 SpotSense (Sonora Data, LLC). All rights

import Foundation
import CoreLocation
import UserNotifications

open class Rule {
    public let notificationCenter = UNUserNotificationCenter.current()

    public let enabled: Bool
    public let id: String
    public let geofence: Geofence
    public let name: String
    public let locationManager: CLLocationManager = CLLocationManager()

    
    public init (ruleDict: NSDictionary) {
        
        self.enabled = ruleDict["enabled"] as! Bool
        self.id = ruleDict["id"] as! String
        self.geofence = Geofence(geofenceDict: ruleDict["geofence"] as! [String:Any])
        self.name = ruleDict["geofenceName"] as? String ?? ""
        
    }
    
        open func initGeofence() {

            let geofenceRegionCenter = self.geofence.center
            let geofenceRegion = CLCircularRegion(center: geofenceRegionCenter, radius: CLLocationDistance(self.geofence.radiusSize), identifier: self.id)
            geofenceRegion.notifyOnExit = true
            geofenceRegion.notifyOnEntry = true
            locationManager.startMonitoring(for: geofenceRegion)
        }
        
        open func scheduleNotification() {

//            if (self.getActionType() == "notification") {
                let content = UNMutableNotificationContent()
                content.title = self.name
                content.body = "Inner SDK notification"
            content.sound = UNNotificationSound.default

                let center = self.geofence.center
                let region = CLCircularRegion(center: center, radius: self.geofence.radiusSize, identifier: self.id)
                region.notifyOnEntry = true
                region.notifyOnExit = true

                switch self.getTriggerType() {
                    case "enters":
                        region.notifyOnEntry = true
                        region.notifyOnExit = true
                    case "exits":
                        region.notifyOnEntry = true
                        region.notifyOnExit = true
                    case "returns":
                        region.notifyOnEntry = true
                        region.notifyOnExit = true
                    default:
                        region.notifyOnEntry = true
                        region.notifyOnExit = true
                }
                
                let trigger = UNLocationNotificationTrigger(region: region, repeats: true)
                let request = UNNotificationRequest(identifier: self.id, content: content, trigger: trigger)
                
                notificationCenter.add(request) { (error) in
                    if error != nil {
                        print("\(String(describing: error))")  // compiler warning patched
                    } else {
                        print("Added notification to center")
                    }
                }
//            }
//            else {
//                print("Not a notification")
//            }
            
        }

    open func removeNotification() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [self.id])
    }
    
    open func getActionType() -> String {
        return  ""//jatinself.action.actionType.rawValue
    }
    
    open func getTriggerType() -> String {
        return ""//self.trigger.triggerType.rawValue
    }
    
    open func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Play sound and show alert to the user
        print("Showing notification")
        completionHandler([.alert,.sound])
    }
    
    open func triggerSegue(segueID: String) {
        // TODO: implement
        print("We need to trigger \(segueID)")
    }
    
    func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
}

open class Trigger {
    public enum triggerType: String {
        case enters
        case exits
        case dwells
        case returns
    }
    
    public let time: Int
    public let triggerType: triggerType
    
    public init (triggerDict: NSDictionary) { // time is 0 when not a dwell rule
        if let t = triggerDict["time"] as? Int {
            self.time = t
        } else {
            self.time = 0
        }
        
        let triggerTypeStr = triggerDict["triggerType"] as! String
        
        switch triggerTypeStr {
            case "enters":
                self.triggerType = .enters
            case "exits":
                self.triggerType = .exits
            case "dwells":
                self.triggerType = .dwells
            case "returns":
                self.triggerType = .returns
            default:
                self.triggerType = .enters
        }
    }
}

open class Geofence {
    public let center: CLLocationCoordinate2D
    public let radiusSize:Double
    
//    public let geofenceType:geofenceType
//    public enum geofenceType: String {
//        case radius
//        case polygon
//    }
    
    public init(geofenceDict: [String : Any]) {
        let centerDict = geofenceDict["center"] as! NSDictionary
        
        let latStr = centerDict["lat"] as! Double
        let lonStr = centerDict["long"] as! Double
        let lat = Double(latStr)
        let lon = Double(lonStr)
        self.center = CLLocationCoordinate2DMake(lat, lon)

        let radiusSize = geofenceDict["radiusSize"] as! Double
        self.radiusSize = radiusSize
        
//        let geofenceTypeStr = geofenceDict["geofenceType"] as? String
//
//        switch geofenceTypeStr { // polygon not supported yet
//            case "radius":
//                self.geofenceType = .radius
//            default:
//                self.geofenceType = .radius
//            }
        }

}

open class Action {
    public let actionType: actionType
    public enum actionType: String {
        case notification
        case segue
        case monitor
        case http
    }
    
    public var message:String?
    public var segueID:String?

    public init(actionDict: NSDictionary) {
        let actionTypeStr = actionDict["actionType"] as! String
        
        switch actionTypeStr {
            case "notification":
                self.actionType = .notification
                self.message = (actionDict["message"] as! String)
            case "segue":
                self.actionType = .segue
                self.segueID = (actionDict["segueID"] as! String)
            case "monitor":
                self.actionType = .monitor
            case "http":
                self.actionType = .http
            default:
                self.actionType = .monitor
        }
    }
}

open class NotifyResponse {
    public let triggered:Bool
    public let message:String
    public var action:Action?
    public var httpResponse:NSDictionary?
    public var segueID:String?
    
    public init(responseDict: NSDictionary) {
        self.triggered = responseDict["triggered"] as! Bool
        self.message = responseDict["message"] as! String
        if (self.triggered) {
            if let actionDict = responseDict["action"] as? NSDictionary {
                self.action = Action(actionDict: actionDict)
                print("Type in constructor: \(self.getActionType())")
                if (self.getActionType() == "segue") {
                    self.segueID = action?.segueID
                }
            } else if let httpResponseDict = responseDict["httpResponse"] as? NSDictionary {
                self.httpResponse = httpResponseDict
            }
        }
    }
    
    open func getHTTPResponse() -> NSDictionary? {
        return self.httpResponse
    }
    
    open func getActionType() -> String {
        if let action = self.action {
            return action.actionType.rawValue
        } else {
            return ""
        }
    }
}

class Logger {

     var logFile: URL? {
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        let dateString = formatter.string(from: Date())
        let fileName = "\(dateString).log"
        
        return documentsDirectory.appendingPathComponent(fileName)
    }

     func log(_ message: String) {
        guard let logFile = logFile else {
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timestamp = formatter.string(from: Date())
        guard let data = (timestamp + ": " + message + "\n").data(using: String.Encoding.utf8) else { return }

        if FileManager.default.fileExists(atPath: logFile.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: logFile, options: .atomicWrite)
        }
    }
}
