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
import Alamofire
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

    let spotsenseURL = "https://3o7us23hzl.execute-api.us-west-1.amazonaws.com/roor"
    
    //Beacon
    var onLostTimeout: Double = 15.0

    public var centralManager: CBCentralManager!
    public let beaconOperationsQueue = DispatchQueue(label: "beacon_operations_queue")
    public var shouldBeScanning = false

    public var seenEddystoneCache = [String : [String : AnyObject]]()
    public var deviceIDCache = [UUID : NSData]()

    
    public init(clientID: String, clientSecret: String) { // init this spotsense instant
        
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.deviceID = (UIDevice.current.identifierForVendor?.uuidString)!
        print(self.deviceID)
        
        super.init()

        OperationQueue.main.addOperation{
            self.locationManager = CLLocationManager()
        }
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
        let auth0URL = "https://spotsense.auth0.com/oauth/token"
        let tokenHeaders: HTTPHeaders = [
            "content-type": "application/json"
        ]
        
        let tokenParameters: Parameters = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "audience": "https://api.spotsense.io/beta",
            "grant_type":"client_credentials"
        ]

        Alamofire.request("\(auth0URL)", method: .post, parameters: tokenParameters, encoding: JSONEncoding.default, headers: tokenHeaders)
            .responseJSON { response in
                if let result = response.result.value {
                    let JSON = result as! NSDictionary
                    
                    if let token = JSON["access_token"] {
                        completion((token as! String), nil)
                    } else {
                        completion(nil, "Unable to get access_token")
                    }
                } else {
                    completion(nil, "Alamofire error")
                }
        }
    }
    
    private func setToken(tokenStr: String) {
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
        let header: HTTPHeaders = [
            "content-type": "application/json",
            "Authorization": "Bearer \(self.token!)"
        ]
        
        let parameters: Parameters = [
            "deviceID": id,
            "customID": "Waddup from the SDK Playground"
        ]

        Alamofire.request("\(spotsenseURL)/\(self.clientID)/users", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: header).responseJSON { response in
            switch response.result {
            case .success( _):
                print("User Response: \(String(describing: response.result.value))")
                completion()
            case .failure(let error):
                print("\n Failure: \(error.localizedDescription)")
                completion()
            }
        }
    }
    
    private func userExists(completion: @escaping (Bool) -> Void) {
        // call out to get user by id
        let tokenHeaders: HTTPHeaders = [
            "content-type": "application/json",
            "Authorization": "Bearer \(self.token!)"
        ]
        
        let expectedUserID = "\(self.clientID)-\(self.deviceID)"
    
        Alamofire.request("\(spotsenseURL)/\(self.clientID)/users/\(expectedUserID)", method: .get, parameters: nil, encoding: JSONEncoding.default, headers: tokenHeaders).responseJSON { response in
            switch response.result {
                
            case .success( _):
                if let res = response.result.value as? NSDictionary {
                    if res["errorMessage"] != nil { // need to test
                        completion(false)
                    } else {
                        completion(true)
                    }
                } else {
                    print("Error converting to JSON")
                    completion(false)
                }

            case .failure(let error):
                print("\n Failure: \(error.localizedDescription)")
                completion(false)
            }
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
        if let enabled = self.notificationsEnabled {
            if enabled {
                return true
            }
            return false
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
        
        let tokenHeaders: HTTPHeaders = [
            "content-type": "application/json",
            "Authorization": "Bearer \(self.token!)"
        ]
        
        Alamofire.request("\(spotsenseURL)/apps/\(self.clientID)", parameters: nil, encoding: JSONEncoding.default, headers: tokenHeaders).responseJSON { response in
            switch response.result {
                case .success( _):
                    if let app = response.result.value as? NSDictionary {
                        if let name = app["name"] {
                            print ("Name: \(name)")
                            let appRes = SpotSenseApp(appID: self.clientID, appName: name as! String)
                            completion(appRes)
                        } else {
                            print("Couldn't get name from JSON object")
                            completion(nil)
                        }
                    } else {
                        print("Error converting to JSON")
                        completion(nil)
                    }
                case .failure(let error):
                    print("\n Failure: \(error.localizedDescription)")
                    completion(nil)
            }
        }
    }

            open func getRules(completion: @escaping () -> ()) {
                self.getToken {
                    let tokenHeaders: HTTPHeaders = [
                        "content-type": "application/json",
                        "Authorization": "Bearer \(self.token!)"
                    ]
                    
                    Alamofire.request("\(self.spotsenseURL)/\(self.clientID)/rules", parameters: nil, encoding: JSONEncoding.default, headers: tokenHeaders).responseJSON { response in
                        switch response.result {
                            case .success( _):
                                if let res = response.result.value as? NSDictionary {
                                    if let rules = res["rules"] as? NSArray {
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
                                } else {
                                    print("Error converting to JSON")
                                    completion()
                                }
                            case .failure(let error):
                                print("\n Failure: \(error.localizedDescription)")
                                completion()
                        }
                    }
                }
            }
    
    open func getBeacons(completion: @escaping () -> ()) {
        self.getToken {
            let tokenHeaders: HTTPHeaders = [
                "content-type": "application/json",
                "Authorization": "Bearer \(self.token!)"
            ]
            
            Alamofire.request("\(self.spotsenseURL)/\(self.clientID)/beaconRules", parameters: nil, encoding: JSONEncoding.default, headers: tokenHeaders).responseJSON { response in
                switch response.result {
                    case .success( _):
                        if let res = response.result.value as? NSDictionary {
                            if let beacons = res["beaconRules"] as? NSArray {
                                // clear out previously scheduled notifications as they tend to get improperly cached
                                self.notificationCenter.removeAllPendingNotificationRequests()
                                
                                for beconAny in beacons {
                                    if let beconDict = beconAny as? NSDictionary {
                                        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                                            self.beacons.append(beconDict) // add to array to keep track
                                    }
                                }
                                self.startScanning()

                            } else {
                                print("unable to convert to nsarray")
                            }
                            completion()
                        } else {
                            print("Error converting to JSON")
                            completion()
                        }
                    case .failure(let error):
                        print("\n Failure: \(error.localizedDescription)")
                        completion()
                }
            }
        }
    }
    
    /* Trigger Methods */
    open func handleRegionState(region: CLRegion, state: CLRegionState) {
        let ruleID = region.identifier
        
        self.getToken {
                  let tokenHeaders: HTTPHeaders = [
                             "content-type": "application/json",
                             "Authorization": "Bearer \(self.token!)"
                         ]
               
        let parameters: Parameters = [
            "userID": "\(self.clientID)-\(self.deviceID)"
        ]
        
        print(parameters)
        
        print("\(self.spotsenseURL)/\(self.clientID)/rules/\(ruleID)/enter")
        
        if state == .inside { // equivalent to an enter
            print("Notify enter for region: \(region.identifier)")
            
           // self.fireNotification(notificationText: "Did Arrive: \(region.identifier) region.", didEnter: true)

            Alamofire.request("\(self.spotsenseURL)/\(self.clientID)/rules/\(ruleID)/enter", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: tokenHeaders).responseJSON { response in
                switch response.result {
                case .success(let data):
                    if data is NSDictionary {
                    }
                case .failure(let error):
                    print("\n Failure: \(error.localizedDescription)")
                }
            }
        } else if state == .outside {
            print("Notify exit for region: \(region.identifier)")
            
            
           // self.fireNotification(notificationText: "Did Exit: \(region.identifier) region", didEnter: false)
            //self.localNotification(notificationText: "Did Exit: \(region.identifier) region", didEnter: false)

            Alamofire.request("\(self.spotsenseURL)/\(self.clientID)/rules/\(ruleID)/exit", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: tokenHeaders).responseJSON { response in
                switch response.result {
                case .success(let data):
                    if data is NSDictionary {
                    }
                case .failure(let error):
                    print("\n Failure: \(error.localizedDescription)")
               }
            }
          }
        }
      }
    
    open func handleBeaconEnterState(beaconScanner: SpotSense, beaconInfo: BeaconInfo ,data: NSDictionary) {
      
        let ruleID = data["id"] as! String
        
        self.getToken {
                  let tokenHeaders: HTTPHeaders = [
                             "content-type": "application/json",
                             "Authorization": "Bearer \(self.token!)"
                         ]
               
        let parameters: Parameters = [
            "userID": "\(self.clientID)-\(self.deviceID)"
        ]
        
        
        print("\(self.spotsenseURL)/\(self.clientID)/beaconRules/\(ruleID)/enter")
                    
           // self.fireNotification(notificationText: "Did Arrive: \(ruleID) Beacon.", didEnter: true)

            Alamofire.request("\(self.spotsenseURL)/\(self.clientID)/beaconRules/\(ruleID)/enter", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: tokenHeaders).responseJSON { response in
                switch response.result {
                    
                case .success(let data):
                    if data is NSDictionary {
                       // self.handleNotifyResponse(response: obj, ruleID: ruleID)
                    }
                case .failure(let error):
                    print("\n Failure: \(error.localizedDescription)")
                }
            }
        }
      }

    open func handleBeaconExitState(beaconScanner: SpotSense, beaconInfo: BeaconInfo ,data: NSDictionary) {
      
       // let ruleID = beaconInfo.description
        
        let ruleID = data["id"] as! String

        self.getToken {
                  let tokenHeaders: HTTPHeaders = [
                             "content-type": "application/json",
                             "Authorization": "Bearer \(self.token!)"
                         ]
               
        let parameters: Parameters = [
            "userID": "\(self.clientID)-\(self.deviceID)"
        ]
        
        print(parameters)
        
        print("\(self.spotsenseURL)/\(self.clientID)/beaconRules/\(ruleID)/exit")
        
            print("Notify exit for beacon: \(ruleID)")
                        
          //  self.fireNotification(notificationText: "Did Exit: \(ruleID) beacon", didEnter: false)

            Alamofire.request("\(self.spotsenseURL)/\(self.clientID)/beaconRules/\(ruleID)/exit", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: tokenHeaders).responseJSON { response in
                switch response.result {
                case .success(let data):
                    if data is NSDictionary {
                        
                        //self.handleNotifyResponse(response: obj, ruleID: ruleID)
                    }
                case .failure(let error):
                    print("\n Failure: \(error.localizedDescription)")
               }
        }
      }
    }

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
//func ruleDidTrigger(response: NotifyResponse, ruleID: String) {
//
//       if let segueID = response.segueID { // performs screenchange
//                  performSegue(withIdentifier: segueID, sender: nil)
//              } else if (response.getActionType() == "http") {
//                  _ = response.getHTTPResponse()
//              }
//   }
