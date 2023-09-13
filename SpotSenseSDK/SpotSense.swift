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
//  SpotSense.swift
//
//  Copyright © 2018 SpotSense (Sonora Data, LLC). All rights

/*
 Public Methods:
 * getAppInfo() -> [String: Any]
 * getUser() -> [String: Any]
 * getRules() -> [String: RuleObject]
 * notifyEnter() -> ActionObject
 * notifyVoid() -> ActionObject
 * notifyDwell() -> ActionObject
*/

import Foundation
import Dispatch
import JWTDecode
import CoreLocation
import UserNotifications
import CoreBluetooth

public protocol SpotSenseDelegate {
    func ruleDidTrigger(response: NotifyResponse, ruleID: String)
    func didFindBeacon(beaconScanner: SpotSense, beaconInfo: BeaconInfo, data : NSDictionary)
    func didLoseBeacon(beaconScanner: SpotSense, beaconInfo: BeaconInfo, data : NSDictionary)
    func didUpdateBeacon(beaconScanner: SpotSense, beaconInfo: BeaconInfo , data : NSDictionary)
    func didObserveURLBeacon(beaconScanner: SpotSense, URL: NSURL, RSSI: Int)
}

open class SpotSense: NSObject, CBCentralManagerDelegate {
   
    
    public var delegate:SpotSenseDelegate?
    public var clientID: String
    public var clientSecret: String
    public var deviceID: String
    
    public var token: String?
    public var appInfo: SpotSenseApp?
    public var rules = [Rule]()
    public var beacons = [NSDictionary]()
    public var notificationsEnabled:Bool?
    public var locationEnabled:CLAuthorizationStatus?
    public var segueTriggered:Bool = false
    
    public var locationManager:CLLocationManager?
    public let notificationCenter = UNUserNotificationCenter.current()

    //Beacon
    var onLostTimeout: Double = 15.0

    public var centralManager: CBCentralManager!
    public let beaconOperationsQueue = DispatchQueue(label: "beacon_operations_queue")
    public var shouldBeScanning = false

    public var seenEddystoneCache = [String : [String : AnyObject]]()
    public var deviceIDCache = [UUID : NSData]()
    private let networkManager = NetworkManager.shared

    
    public init(clientID: String, clientSecret: String) { // init this spotsense instant
        
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.deviceID = (UIDevice.current.identifierForVendor?.uuidString)!
        print(self.deviceID)
        
        super.init()

//        OperationQueue.main.addOperation{
            self.locationManager = CLLocationManager()
//        }
        self.centralManager = CBCentralManager(delegate: self, queue: self.beaconOperationsQueue)
        self.centralManager.delegate = self

        self.initApp(completion: {
            print("Spotsense initialization complete")
        })
    }

    private func initApp(completion: @escaping () -> Void) {
        let token_dispatchGroup = DispatchGroup()
        
        token_dispatchGroup.enter()
        
        self.getToken(completion: {
            
            token_dispatchGroup.leave()
        })
        
        // do our async jazz and then when done
        
        token_dispatchGroup.notify(queue: .main) {
            // print("Token: \(self.token!)")

            /* we have access to self.token now */
            let getInfo_dispatchgroup = DispatchGroup();

            // get app info
            getInfo_dispatchgroup.enter()
            
            self.getAppInfo { app in
                self.appInfo = app
                getInfo_dispatchgroup.leave()
            }

            // get rules
            getInfo_dispatchgroup.enter()
            self.getRules {
                getInfo_dispatchgroup.leave()
            }
            
            // get beacons
            getInfo_dispatchgroup.enter()
            self.getBeacons {
                getInfo_dispatchgroup.leave()
            }
            
            
            // init user
            getInfo_dispatchgroup.enter()
            self.initUser {
                getInfo_dispatchgroup.leave()
            }
            
            // finish up
            getInfo_dispatchgroup.notify(queue: .main) {
                completion()
            }
        }
    }
    
    /* Token Fetching */
    private func getToken(completion: @escaping () -> Void) {
        if self.token != nil {
            completion()
        } else {
            fetchToken { (tokenVal, errCode) in
                if let t = tokenVal {
                    self.setToken(tokenStr: t)
                    completion()
                } else {
                    print("Error getting token")
                    completion()
                }
            }
        }
    }
    
    private func fetchToken (completion: @escaping (String?, String?) -> ()) -> Void {
        let tokenParameters: Parameters = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "audience": "https://api.spotsense.io/beta",
            "grant_type":"client_credentials"
        ]
        
        networkManager.getToken(param: tokenParameters) { jsonResponse in
            if let token = jsonResponse["access_token"] as? String {
                completion((token), nil)
            } else {
                completion(nil, "Unable to get access_token")
            }
        } errorHandler: { error in
            completion(nil, "Network error")
        }
    }
    
    private func setToken(tokenStr: String) {
//        print("Got the token")
        NetworkManager.token = tokenStr
        self.token = tokenStr
    }
    
    private func validateToken(token: String) -> Bool {
        do {
            let _ = try decode(jwt: token)
            return true;
        } catch {
            print("Failed to decode JWT: \(error)")
            return false;
        }
    }
    
    /* User Creation */
    private func initUser(completion: @escaping () -> Void) {
        self.userExists(completion: { exists in
            if (exists) {
                completion()
            } else {
                self.createUser {
                    completion()
                }
            }
        })
    }
    
    private func getDeviceID() -> String{
        return self.deviceID
    }
    
    private func createUser(completion: @escaping () -> Void) {
        // create a user with the ID
        let id = self.deviceID;
        // do the logic for creating a new user
        let parameters: Parameters = [
            "deviceID": id,
            "customID": "Waddup from the SDK Playground"
        ]
        
        networkManager.createUser(param: parameters,
                                         clientID: self.clientID,
                                         completion: completion) { error in
        }
    }
    
    private func userExists(completion: @escaping (Bool) -> Void) {
        // call out to get user by id
        let expectedUserID = "\(self.clientID)-\(self.deviceID)"
        
        networkManager.userExists(clientID: self.clientID,
                                  userID: expectedUserID,
                                  completion: completion) { error in
            
        }
    }
    
    open func notificationStatus(enabled: Bool) {
        self.notificationsEnabled = enabled
        
        if enabled {
            print("Notifications enabled")
        } else {
            print("Notifications not enabled")
        }
    }
    
    open func canNotify() -> Bool {
        if let enabled = self.notificationsEnabled, enabled {
            return true
        } else {
            return false
        }
    }
    
    open func locationStatus(status: CLAuthorizationStatus) {
        self.locationEnabled = status
        
        if (status == CLAuthorizationStatus.authorizedAlways) {
            print("Authorized always")
        } else if (status == CLAuthorizationStatus.authorizedWhenInUse) {
            print("Authorized when in use")
        } else if (status == CLAuthorizationStatus.notDetermined) {
            print("not determined")
        } else if (status == CLAuthorizationStatus.restricted) {
            print("distracted")
        } else if (status == CLAuthorizationStatus.denied) {
            print("Denied")
        }
    }
    
    /* Fetching App Info + Rules */
    open func getAppInfo(completion: @escaping (SpotSenseApp?) -> Void) {
        // gets app info from SpotSense API and returns it as an object
        
        networkManager.getAppInfo(clientId: self.clientID) { name in
            if let name = name {
                let appRes = SpotSenseApp(appID: self.clientID, appName: name)
                completion(appRes)
            } else {
                print("Couldn't get name from JSON object")
                completion(nil)
            }
        } errorHandler: { error in
            
        }
    }
    
    open func getRules(completion: @escaping () -> ()) {
        self.getToken {
            self.networkManager.getRules(clientID: self.clientID) { jsonResponse in
                if let rules = jsonResponse["rules"] as? NSArray {
                    // clear out previously scheduled notifications as they tend to get improperly cached
                    self.notificationCenter.removeAllPendingNotificationRequests()
                    
                    for ruleAny in rules {
                        if let ruleDict = ruleAny as? NSDictionary { // get the individual rule object
                            let rule = Rule(ruleDict: ruleDict )
                            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                            if rule.enabled {
                                print("\(rule.id) is enabled")
                                rule.initGeofence() // create listener for region
                                rule.scheduleNotification() // schedule notification, does nothing if actionType !== 'notification'
                                self.rules.append(rule) // add to array to keep track
                            }
                        }
                    }
                } else {
                    print("unable to convert to nsarray")
                }
                completion()
            } errorHandler: { error in
                completion()
            }
        }
    }
    
    open func getBeacons(completion: @escaping () -> ()) {
        self.getToken {
            self.networkManager.getBeacons(clientID: self.clientID) { jsonResponse in
                if let beacons = jsonResponse["beaconRules"] as? NSArray {
                    // clear out previously scheduled notifications as they tend to get improperly cached
                    self.notificationCenter.removeAllPendingNotificationRequests()
                    
                    for beconAny in beacons {
                        if let beconDict = beconAny as? NSDictionary { // get the individual rule object
                            // let becon = Rule(ruleDict: beconDict )
                            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                            self.beacons.append(beconDict) // add to array to keep track
                        }
                    }
                    
                    self.startScanning()
                    
                } else {
                    print("unable to convert to nsarray")
                }
                completion()
            } errorHandler: { error in
                completion()
            }
        }
    }
    
    /* Trigger Methods */
    open func handleRegionState(region: CLRegion, state: CLRegionState) {
        let ruleID = region.identifier
        
        self.getToken {
            
            let parameters: Parameters = [
                "userID": "\(self.clientID)-\(self.deviceID)"
            ]
            
            print(parameters)
            
            
            if state == .inside { // equivalent to an enter
                print("Notify enter for region: \(region.identifier)")
                
                let logg = Logger()
                logg.log(" Enter : \(region.identifier)")
                
                // self.fireNotification(notificationText: "Did Arrive: \(region.identifier) region.", didEnter: true)
                //self.localNotification(notificationText: "Did Arrive: \(region.identifier) region.", didEnter: true)
                
                self.networkManager.regionStateEnter(clientID: self.clientID,
                                                     ruleID: ruleID,
                                                     param: parameters) { jsonResponse in
                    // self.handleNotifyResponse(response: obj, ruleID: ruleID)
                } errorHandler: { error in
                    print("\n Failure: \(error ?? "")")
                }
            } else if state == .outside {
                print("Notify exit for region: \(region.identifier)")
                
                let logg = Logger()
                logg.log(" Exit :  \(region.identifier)")
                
                // self.fireNotification(notificationText: "Did Exit: \(region.identifier) region", didEnter: false)
                //self.localNotification(notificationText: "Did Exit: \(region.identifier) region", didEnter: false)
                
                self.networkManager.regionStateExist(clientID: self.clientID, ruleID: ruleID, param: parameters) { jsonResponse in
                    //self.handleNotifyResponse(response: obj, ruleID: ruleID)
                } errorHandler: { error in
                    print("\n Failure: \(error ?? "")")
                }
            }
        }
    }
    
    open func handleLocationUpdate(location: CLLocation) {
        
        self.getToken {
            let parameters: Parameters = [
                "deviceID": "\(self.deviceID)",
                "location": "\(location)"
            ]
            
            self.networkManager.updateLocation(clientID: self.clientID, param: parameters) { jsonResponse in
                
            } errorHandler: { error in
                print("\n Failure: \(error ?? "")")
            }
        }
    }
    
    open func handleBeaconEnterState(beaconScanner: SpotSense, beaconInfo: BeaconInfo ,data: NSDictionary) {
        
        let ruleID = data["id"] as! String
        
        //   print(ruleID)
        self.getToken {
            let parameters: Parameters = [
                "userID": "\(self.clientID)-\(self.deviceID)"
            ]
            
            //   print("Notify enter for beacon: \(ruleID)")
            
            let logg = Logger()
            logg.log(" Enter : \(ruleID)")
            
            // self.fireNotification(notificationText: "Did Arrive: \(ruleID) Beacon.", didEnter: true)
            
            self.networkManager.beaconEnterState(clientID: self.clientID,
                                                 ruleID: ruleID,
                                                 param: parameters) { jsonResponse in
                // self.handleNotifyResponse(response: obj, ruleID: ruleID)
            } errorHandler: { error in
                print("\n Failure: \(error ?? "")")
            }
        }
    }

    open func handleBeaconExitState(beaconScanner: SpotSense, beaconInfo: BeaconInfo ,data: NSDictionary) {
        
        // let ruleID = beaconInfo.description
        
        let ruleID = data["id"] as! String
        
        self.getToken {
            
            let parameters: Parameters = [
                "userID": "\(self.clientID)-\(self.deviceID)"
            ]
            
            print("Notify exit for beacon: \(ruleID)")
            
            let logg = Logger()
            logg.log(" Exit :  \(ruleID)")
            
            // self.fireNotification(notificationText: "Did Exit: \(ruleID) beacon", didEnter: false)
            
            self.networkManager.beaconExitState(clientID: self.clientID, ruleID: ruleID, param: parameters) { jsonResponse in
                //self.handleNotifyResponse(response: obj, ruleID: ruleID)
            } errorHandler: { error in
                print("\n Failure: \(error ?? "")")
            }
        }
    }

    
//    func localNotification(notificationText: String, didEnter: Bool) {
//
//       let content = UNMutableNotificationContent()
//        content.title = NSString.localizedUserNotificationString(forKey: didEnter ? "Local Entered Region" : "Local Exited Region", arguments: nil)
//        content.body = NSString.localizedUserNotificationString(forKey: notificationText, arguments: nil)
//        content.sound = UNNotificationSound.default()
//        content.categoryIdentifier = "notify-test"
//
//        let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: 4, repeats: false)
//        let request = UNNotificationRequest.init(identifier: notificationText, content: content, trigger: trigger)
//
//        let center = UNUserNotificationCenter.current()
//        center.add(request)
//
//    }
//
    func fireNotification(notificationText: String, didEnter: Bool) {
        let notificationCenter = UNUserNotificationCenter.current()
        
        notificationCenter.getNotificationSettings { (settings) in
            if settings.alertSetting == .enabled {
                let content = UNMutableNotificationContent()
                content.title = didEnter ? "Entered Region" : "Exited Region"
                content.body = notificationText
                content.sound = UNNotificationSound.default
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                
                let request = UNNotificationRequest(identifier: notificationText, content: content, trigger: trigger)
                
                notificationCenter.add(request, withCompletionHandler: { (error) in
                    if error != nil {
                        // Handle the error
                    }
                })
            }
        }
    }

    open func handleNotifyResponse(response: NSDictionary, ruleID: String) {
        let notifyResponse = NotifyResponse(responseDict: response)
        
        if notifyResponse.triggered {
            switch notifyResponse.getActionType() {
                case "segue":
                    if let segueID = notifyResponse.segueID {
                        print("We need to trigger \(segueID)")
                        // TODO: pass to view controller to perform segue
                    }
                case "http":
                    print("HTTP Response: \(String(describing: notifyResponse.getHTTPResponse()))")
                    // TODO: pass to view controller
                case "notification":
                    print("REPLACE: triggering notification")
                // TODO: handle the returns scheduling here
                default:
                    print("REPLACE: Didn't do anything")
            }
            delegate?.ruleDidTrigger(response: notifyResponse, ruleID: ruleID) // pass data to view controller
        } else {
//            spotsense.resetSegue()
            print("No trigger")
        }
    }
    
    /* Segue Handlers */
    open func triggerSegue() {
        self.segueTriggered = true
    }

    open func resetSegue() {
        self.segueTriggered = false
    }

    open func segueStatus() -> Bool {
        return self.segueTriggered
    }

    /* Per-User Rules */
    open func enableClosestRuleForUser(completion: @escaping () -> ()) {
        completion()
    }

    open func disableClosestRuleForUser(completion: @escaping () -> ()) {
        completion()
    }
    
    //beacon
    
    ///
    /// Start scanning. If Core Bluetooth isn't ready for us just yet, then waits and THEN starts
    /// scanning.
    ///
   public func startScanning() {
      beaconOperationsQueue.async {
        self.startScanningSynchronized()
      }
    }

    ///
    /// Stops scanning for Eddystone beacons.
    ///
   public func stopScanning() {
      self.centralManager.stopScan()
    }

    ///
    /// MARK - private methods and delegate callbacks
    ///
      public func centralManagerDidUpdateState(_ central: CBCentralManager) {
      if central.state == .poweredOn && self.shouldBeScanning {
        self.startScanningSynchronized();
      }
    }

    ///
    /// Core Bluetooth CBCentralManager callback when we discover a beacon. We're not super
    /// interested in any error situations at this point in time.
    ///

    public func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
      if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey]
        as? [NSObject : AnyObject] {
        var eft: BeaconInfo.EddystoneFrameType
        eft = BeaconInfo.frameTypeForFrame(advertisementFrameList: serviceData)

        // If it's a telemetry frame, stash it away and we'll send it along with the next regular
        // frame we see. Otherwise, process the UID frame.
        if eft == BeaconInfo.EddystoneFrameType.TelemetryFrameType {
          deviceIDCache[peripheral.identifier] = BeaconInfo.telemetryDataForFrame(advertisementFrameList: serviceData)
        } else if eft == BeaconInfo.EddystoneFrameType.UIDFrameType
                  || eft == BeaconInfo.EddystoneFrameType.EIDFrameType {
          let telemetry = self.deviceIDCache[peripheral.identifier]
          let serviceUUID = CBUUID(string: "FEAA")
          let _RSSI: Int = RSSI.intValue

          if let beaconServiceData = serviceData[serviceUUID] as? NSData,
            let beaconInfo =
              (eft == BeaconInfo.EddystoneFrameType.UIDFrameType
                ? BeaconInfo.beaconInfoForUIDFrameData(frameData: beaconServiceData, telemetry: telemetry,
                                                       RSSI: _RSSI)
                : BeaconInfo.beaconInfoForEIDFrameData(frameData: beaconServiceData, telemetry: telemetry,
                                                       RSSI: _RSSI)) {

            // NOTE: At this point you can choose whether to keep or get rid of the telemetry
            //       data. You can either opt to include it with every single beacon sighting
            //       for this beacon, or delete it until we get a new / "fresh" TLM frame.
            //       We'll treat it as "report it only when you see it", so we'll delete it
            //       each time.
            
            self.deviceIDCache.removeValue(forKey: peripheral.identifier)

            if (self.seenEddystoneCache[beaconInfo.beaconID.description] != nil) {
              // Reset the onLost timer and fire the didUpdate.
              if let timer =
                self.seenEddystoneCache[beaconInfo.beaconID.description]?["onLostTimer"]
                  as? DispatchTimer {
                timer.reschedule()
              }
                
                for dic in beacons {
                    
                    let str = dic["namespace"] as! String
                    
//                    let str1 = String(beaconInfo.beaconID.description.prefix(20))
                    let str1 = beaconInfo.beaconID.description

                  
                    if str1.range(of:str) != nil {
                                self.delegate?.didUpdateBeacon(beaconScanner: self, beaconInfo: beaconInfo,data: dic)
                    }
                }
                
            } else {
              // We've never seen this beacon before
                

                for dic in beacons {
                    
                    let str = dic["namespace"] as! String
                    
//                    let str1 = String(beaconInfo.beaconID.description.prefix(20))
                    let str1 = beaconInfo.beaconID.description
                   
                    if str1.range(of:str) != nil {
                        self.delegate?.didFindBeacon(beaconScanner: self, beaconInfo: beaconInfo, data: dic)
                    }
                }
                
              let onLostTimer = DispatchTimer.scheduledDispatchTimer(
                delay: self.onLostTimeout,
                queue: DispatchQueue.main) {
                  (timer: DispatchTimer) -> () in
                  let cacheKey = beaconInfo.beaconID.description
                  if let
                    beaconCache = self.seenEddystoneCache[cacheKey],
                    let lostBeaconInfo = beaconCache["beaconInfo"] as? BeaconInfo {
                    
                    for dic in self.beacons {
                                       
                                       let str = dic["namespace"] as! String
                                       
//                                       let str1 = String(beaconInfo.beaconID.description.prefix(20))
                                    let str1 = beaconInfo.beaconID.description
                        
                                    if str1.range(of:str) != nil {
                                            self.delegate?.didLoseBeacon(beaconScanner: self, beaconInfo: lostBeaconInfo, data : dic)
                                        }
                                }
                    
                    self.seenEddystoneCache.removeValue(
                      forKey: beaconInfo.beaconID.description)
                  }
              }

              self.seenEddystoneCache[beaconInfo.beaconID.description] = [
                "beaconInfo" : beaconInfo,
                "onLostTimer" : onLostTimer
              ]
            }
          }
        } else if eft == BeaconInfo.EddystoneFrameType.URLFrameType {
          let serviceUUID = CBUUID(string: "FEAA")
          let _RSSI: Int = RSSI.intValue

          if let beaconServiceData = serviceData[serviceUUID] as? NSData,
            let URL = BeaconInfo.parseURLFromFrame(frameData: beaconServiceData) {
            self.delegate?.didObserveURLBeacon(beaconScanner: self, URL: URL, RSSI: _RSSI)
          }
        }
      } else {
        NSLog("Unable to find service data; can't process Eddystone")
      }
    }

    public func startScanningSynchronized() {
      if self.centralManager.state != .poweredOn {
        NSLog("CentralManager state is %d, cannot start scan", self.centralManager.state.rawValue)
        self.shouldBeScanning = true
      } else {
        NSLog("Starting to scan for Eddystones")
        let services = [CBUUID(string: "FEAA")]
        let options = [CBCentralManagerScanOptionAllowDuplicatesKey : true]
        self.centralManager.scanForPeripherals(withServices: services, options: options)
      }
    }
}
