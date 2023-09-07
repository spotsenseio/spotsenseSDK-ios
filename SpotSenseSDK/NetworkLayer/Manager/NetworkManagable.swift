//
//  NetworkManagable.swift
//  SpotSenseSDK
//
//  Created by Vibhor Jain on 06/09/23.
//  Copyright © 2023 SpotSense. All rights reserved.
//

import Foundation

public protocol NetworkManagable {
    func getToken(param: [String:Any],
                  completion: @escaping (_ jsonResponse: [String:Any]) -> (),
                  errorHandler:@escaping (_ error: String?) -> Void)
    func createUser(param:Parameters,
                    clientID: String,
                    completion: @escaping () -> Void,
                    errorHandler:@escaping (String?) -> Void)
    func userExists(clientID: String,
                    userID: String,
                    completion: @escaping (Bool) -> Void,
                    errorHandler:@escaping (String?) -> Void)
    func getAppInfo(clientId: String,
                    completion: @escaping (_ name: String?) -> Void,
                    errorHandler:@escaping (String?) -> Void)
    func getRules(clientID: String,
                  completion: @escaping (_ jsonResponse: [String:Any]) -> (),
                  errorHandler:@escaping (_ error: String?) -> Void)
    func getBeacons(clientID: String,
                    completion: @escaping (_ jsonResponse: [String:Any]) -> (),
                    errorHandler:@escaping (_ error: String?) -> Void)
    func regionStateEnter(clientID: String,
                          ruleID: String,
                          param: [String:Any],
                          completion: @escaping (_ jsonResponse: [String:Any]) -> (),
                          errorHandler:@escaping (_ error: String?) -> Void)
    func regionStateExist(clientID: String,
                          ruleID: String,
                          param: [String:Any],
                          completion: @escaping (_ jsonResponse: [String:Any]) -> (),
                          errorHandler:@escaping (_ error: String?) -> Void)
    func updateLocation(clientID: String,
                        param: [String:Any],
                        completion: @escaping (_ jsonResponse: [String:Any]) -> (),
                        errorHandler:@escaping (_ error: String?) -> Void)
    func beaconEnterState(clientID: String,
                          ruleID: String,
                          param: [String:Any],
                          completion: @escaping (_ jsonResponse: [String:Any]) -> (),
                          errorHandler:@escaping (_ error: String?) -> Void)
    func beaconExitState(clientID: String,
                          ruleID: String,
                          param: [String:Any],
                          completion: @escaping (_ jsonResponse: [String:Any]) -> (),
                          errorHandler:@escaping (_ error: String?) -> Void)
}
