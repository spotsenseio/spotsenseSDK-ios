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

public protocol SpotSenseDelegate {
    func ruleDidTrigger(response: NotifyResponse, ruleID: String)
}

open class SpotSense {
    public var delegate:SpotSenseDelegate?
    public let clientID: String
    public let clientSecret: String
    public let deviceID: String
    
    public var token: String?
    public var appInfo: SpotSenseApp?
    public var rules = [Rule]()
    public var notificationsEnabled:Bool?
    public var locationEnabled:CLAuthorizationStatus?
    public var segueTriggered:Bool = false
    
    public var locationManager:CLLocationManager?
    public let notificationCenter = UNUserNotificationCenter.current()

    
    // API base URL
    let spotsenseURL = "https://hc5e9wpgpb.execute-api.us-west-1.amazonaws.com/dev"
    
    public init(clientID: String, clientSecret: String) { // init this spotsense instant
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.deviceID = (UIDevice.current.identifierForVendor?.uuidString)!
        
        OperationQueue.main.addOperation{
            self.locationManager = CLLocationManager()
        }
        
        self.initApp(completion: {
            print("Init complete")
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

//            // get rules
//            getInfo_dispatchgroup.enter()
//            self.getRules {
//                getInfo_dispatchgroup.leave()
//            }
            
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
//        print("Got the token")
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
//                pripnt("User Response: \(response.result.value)")
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
        
        // TODO: call out to spotsense API
        
        
//        if (status == CLAuthorizationStatus.authorizedAlways) {
//            print("Authorized always")
//        } else if (status == CLAuthorizationStatus.authorizedWhenInUse) {
//            print("Authorized when in use")
//        } else if (status == CLAuthorizationStatus.notDetermined) {
//            print("not determined")
//        } else if (status == CLAuthorizationStatus.restricted) {
//            print("distracted")
//        } else if (status == CLAuthorizationStatus.denied) {
//            print("Denied")
//        }
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
                                        let rule = Rule(ruleDict: ruleDict)
                                        
                                        if rule.enabled {
//                                            print("\(rule.id) is enabled")
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
    
    
    /* Trigger Methods */
    open func handleRegionState(region: CLRegion, state: CLRegionState) {
        let ruleID = region.identifier
        
        let tokenHeaders: HTTPHeaders = [
            "content-type": "application/json",
            "Authorization": "Bearer \(self.token!)"
        ]
        
        let parameters: Parameters = [
            "userID": "\(self.clientID)-\(self.deviceID)"
        ]
        
        if state == .inside { // equivalent to an enter
            print("Notify enter for region: \(region.identifier)")
            Alamofire.request("\(spotsenseURL)/\(self.clientID)/rules/\(ruleID)/enter", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: tokenHeaders).responseJSON { response in
                switch response.result {
                case .success(let data):
                    if let obj = data as? NSDictionary {
                        self.handleNotifyResponse(response: obj, ruleID: ruleID)
                    }
                case .failure(let error):
                    print("\n Failure: \(error.localizedDescription)")
                }
            }
        } else if state == .outside {
            print("Notify exit for region: \(region.identifier)")
            Alamofire.request("\(spotsenseURL)/\(self.clientID)/rules/\(ruleID)/exit", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: tokenHeaders).responseJSON { response in
                switch response.result {
                case .success(let data):
                    if let obj = data as? NSDictionary {
                        self.handleNotifyResponse(response: obj, ruleID: ruleID)
                    }
                case .failure(let error):
                    print("\n Failure: \(error.localizedDescription)")
                }
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

    
}
