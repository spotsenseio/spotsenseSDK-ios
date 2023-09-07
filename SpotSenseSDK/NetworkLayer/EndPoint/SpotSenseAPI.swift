//
//  SpotSenseAPI.swift
//  SpotSenseSDK
//
//  Created by Samyak Jain on 06/09/23.
//  Copyright © 2023 SpotSense. All rights reserved.
//

import Foundation


enum NetworkEnvironment {
    case production
}

public enum SpotSenseAPI {
    case createUser(param:Parameters,clientID: String)
    case userExists(clientID: String,userID: String)
    case getAppInfo(clientID: String)
    case getRules(clientID: String)
    case getBeacons(clientID: String)
    case regionStateEnter(clientID: String, ruleID: String, param: Parameters)
    case regionStateExit(clientID: String, ruleID: String, param: Parameters)
    case updateLocation(clientID: String, param: Parameters)
    case beaconStateEnter(clientID: String, ruleID: String, param: Parameters)
    case beaconStateExit(clientID: String, ruleID: String, param: Parameters)
}

extension SpotSenseAPI: EndPointType {
    
    var environmentBaseURL : String {
        switch NetworkManager.environment {
        case .production:
            return "https://3o7us23hzl.execute-api.us-west-1.amazonaws.com/roor/"
        }
    }
    
    var baseURL: URL {
        guard let url = URL(string: environmentBaseURL) else { fatalError("baseURL could not be configured.")}
        return url
    }
    
    var path: String {
        switch self {
        case .createUser(_, let clientID):
            return "\(clientID)/users"
        case .userExists(let clientID, let userID):
            return "\(clientID)/users/\(userID)"
        case .getAppInfo( let clientID):
            return "apps/\(clientID)"
        case .getRules(clientID: let clientID):
            return "\(clientID)/rules"
        case .getBeacons(clientID: let clientID):
            return "\(clientID)/beaconRules"
        case .regionStateEnter(let clientID, let ruleID, _):
            return "\(clientID)/rules/\(ruleID)/enter"
        case .regionStateExit(let clientID, let ruleID, _):
            return "\(clientID)/rules/\(ruleID)/exit"
        case .updateLocation(let clientID, _):
            return "\(clientID)/locations"
        case .beaconStateEnter(let clientID, let ruleID, _):
            return "\(clientID)/beaconRules/\(ruleID)/enter"
        case .beaconStateExit(let clientID, let ruleID, _):
            return "\(clientID)/beaconRules/\(ruleID)/exit"
        }
    }
    
    var httpMethod: HTTPMethod {
        switch self {
        case .createUser,.regionStateEnter,
                .regionStateExit,.updateLocation,
                .beaconStateEnter,.beaconStateExit:
            return.post
        default:
            return .get
        }
    }
    
    var task: HTTPTask {
        switch self {
        case .createUser(let param,_):
            return .requestParametersAndHeaders(bodyParameters: param,
                                                bodyEncoding: .jsonEncoding,
                                                urlParameters: nil,
                                                additionHeaders: self.headers)
        case .userExists:
            return .requestParametersAndHeaders(bodyParameters: nil,
                                                bodyEncoding: .jsonEncoding,
                                                urlParameters: nil,
                                                additionHeaders: self.headers)
        case.regionStateEnter(_, _,let param):
            return .requestParametersAndHeaders(bodyParameters: param,
                                                bodyEncoding: .jsonEncoding,
                                                urlParameters: nil,
                                                additionHeaders: self.headers)
        case.regionStateExit(_, _,let param):
            return .requestParametersAndHeaders(bodyParameters: param,
                                                bodyEncoding: .jsonEncoding,
                                                urlParameters: nil,
                                                additionHeaders: self.headers)
        case .updateLocation(_, let param):
            return .requestParametersAndHeaders(bodyParameters: param,
                                                bodyEncoding: .jsonEncoding,
                                                urlParameters: nil,
                                                additionHeaders: self.headers)
        case.beaconStateEnter(_, _,let param):
            return .requestParametersAndHeaders(bodyParameters: param,
                                                bodyEncoding: .jsonEncoding,
                                                urlParameters: nil,
                                                additionHeaders: self.headers)
        case.beaconStateExit(_, _,let param):
            return .requestParametersAndHeaders(bodyParameters: param,
                                                bodyEncoding: .jsonEncoding,
                                                urlParameters: nil,
                                                additionHeaders: self.headers)
        default :
            return .request
        }
    }
    
    var headers: HTTPHeaders? {
        return [
            "content-type": "application/json",
            "Authorization": "Bearer \(NetworkManager.token)"
        ]
    }
}


