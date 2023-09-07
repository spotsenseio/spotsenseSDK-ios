//
//  NetworkManager.swift
//  SpotSenseSDK
//
//  Created by Samyak Jain on 06/09/23.
//  Copyright © 2023 SpotSense. All rights reserved.
//

import Foundation

enum NetworkResponse:String {
    case success
    case authenticationError = "You need to be authenticated first."
    case badRequest = "Bad request"
    case outdated = "The url you requested is outdated."
    case failed = "Network request failed."
    case noData = "Response returned with no data to decode."
    case unableToDecode = "We could not decode the response."
}

enum Result<String>{
    case success
    case failure(String)
}

struct NetworkManager: NetworkManagable {
    
    //MARK: Properties
    
    static let shared = NetworkManager()
    static let environment : NetworkEnvironment = .production
    static let token = ""
    let router = Router<SpotSenseAPI>()
    let tokenRouter = Router<TokenAPI>()
    
    //MARK: Initaiser
    
    private init() {}
    
    //MARK: Protocol Methods
    
    func getToken(param: [String:Any],
                  completion: @escaping (_ jsonResponse: [String:Any]) -> (),
                  errorHandler:@escaping (_ error: String?) -> Void) {
        tokenRouter.request(.getToken(param: param)) { data, response, error in
            if error != nil {
                print("NETWORK ERROR: Please check your network connection.")
                errorHandler(error?.localizedDescription)
            }
            
            if let response = response as? HTTPURLResponse {
                let result = self.handleNetworkResponse(response)
                switch result {
                case .success:
                    guard let responseData = data else {
                        errorHandler(NetworkResponse.noData.rawValue)
                        return
                    }
                    do {
                        let jsonData = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers) as? [String:Any]
                        print(jsonData ?? [:])
                        if let res = jsonData {
                            completion(res)
                        } else {
                            errorHandler(NetworkResponse.unableToDecode.rawValue)
                        }
                    }catch {
                        print(error)
                        errorHandler(NetworkResponse.unableToDecode.rawValue)
                    }
                case .failure(let networkFailureError):
                    errorHandler(networkFailureError.description)
                }
            }
        }
    }
    
    func createUser(param:Parameters,
                    clientID: String,
                    completion: @escaping () -> Void,
                    errorHandler:@escaping (String?) -> Void) {
        
        router.request(.createUser(param: param, clientID: clientID)) { data, response, error in
            if error != nil {
                print("NETWORK ERROR: Please check your network connection.")
                errorHandler(error?.localizedDescription)
            }
            
            if let response = response as? HTTPURLResponse {
                let result = self.handleNetworkResponse(response)
                switch result {
                case .success:
                    completion()
                case .failure(let networkFailureError):
                    errorHandler(networkFailureError.description)
                }
            }
        }
    }
    
    func userExists(clientID: String,
                    userID: String,
                    completion: @escaping (Bool) -> Void,
                    errorHandler:@escaping (String?) -> Void) {
        
        router.request(.userExists(clientID: clientID,
                                   userID: userID)) { data, response, error in
            if error != nil {
                print("NETWORK ERROR: Please check your network connection.")
                errorHandler(error?.localizedDescription)
            }
            
            if let response = response as? HTTPURLResponse {
                let result = self.handleNetworkResponse(response)
                switch result {
                case .success:
                    guard let responseData = data else {
                        errorHandler(NetworkResponse.noData.rawValue)
                        return
                    }
                    do {
                        print(responseData)
                        let jsonData = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers) as? [String:Any]
                        print(jsonData ?? [:])
                        if let res = jsonData as? NSDictionary {
                            if res["errorMessage"] != nil { // need to test
                                completion(false)
                            } else {
                                completion(true)
                            }
                        }
                    }catch {
                        print(error)
                        errorHandler(NetworkResponse.unableToDecode.rawValue)
                    }
                case .failure(let networkFailureError):
                    errorHandler(networkFailureError.description)
                }
            }
        }
    }
    
    func getAppInfo(clientId: String,
                    completion: @escaping (_ name: String?) -> Void,
                    errorHandler:@escaping (String?) -> Void) {
        
        router.request(.getAppInfo(clientID: clientId)) { data, response, error in
            if error != nil {
                print("NETWORK ERROR: Please check your network connection.")
                errorHandler(error?.localizedDescription)
            }
            
            if let response = response as? HTTPURLResponse {
                let result = self.handleNetworkResponse(response)
                switch result {
                case .success:
                    guard let responseData = data else {
                        errorHandler(NetworkResponse.noData.rawValue)
                        return
                    }
                    do {
                        print(responseData)
                        let jsonData = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers) as? [String:Any]
                        print(jsonData ?? [:])
                        if let res = jsonData as? NSDictionary {
                            if let name = res["name"] as? String {
                                print ("Name: \(name)")
                                completion(name)
                            } else {
                                print("Couldn't get name from JSON object")
                                completion(nil)
                            }
                        }
                    }catch {
                        print(error)
                        errorHandler(NetworkResponse.unableToDecode.rawValue)
                    }
                case .failure(let networkFailureError):
                    errorHandler(networkFailureError.description)
                }
            }
        }
    }
    
    func getRules(clientID: String,
                  completion: @escaping (_ jsonResponse: [String:Any]) -> (),
                  errorHandler:@escaping (_ error: String?) -> Void) {
        router.request(.getRules(clientID: clientID)) { data, response, error in
            if error != nil {
                print("NETWORK ERROR: Please check your network connection.")
                errorHandler(error?.localizedDescription)
            }
            
            if let response = response as? HTTPURLResponse {
                let result = self.handleNetworkResponse(response)
                switch result {
                case .success:
                    guard let responseData = data else {
                        errorHandler(NetworkResponse.noData.rawValue)
                        return
                    }
                    do {
                        let jsonData = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers) as? [String:Any]
                        print(jsonData ?? [:])
                        if let res = jsonData {
                            completion(res)
                        } else {
                            errorHandler(NetworkResponse.unableToDecode.rawValue)
                        }
                    }catch {
                        print(error)
                        errorHandler(NetworkResponse.unableToDecode.rawValue)
                    }
                case .failure(let networkFailureError):
                    errorHandler(networkFailureError.description)
                }
            }
        }
    }
    
    func getBeacons(clientID: String,
                    completion: @escaping (_ jsonResponse: [String:Any]) -> (),
                    errorHandler:@escaping (_ error: String?) -> Void) {
        router.request(.getBeacons(clientID: clientID)) { data, response, error in
            if error != nil {
                print("NETWORK ERROR: Please check your network connection.")
                errorHandler(error?.localizedDescription)
            }
            
            if let response = response as? HTTPURLResponse {
                let result = self.handleNetworkResponse(response)
                switch result {
                case .success:
                    guard let responseData = data else {
                        errorHandler(NetworkResponse.noData.rawValue)
                        return
                    }
                    do {
                        let jsonData = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers) as? [String:Any]
                        print(jsonData ?? [:])
                        if let res = jsonData {
                            completion(res)
                        } else {
                            errorHandler(NetworkResponse.unableToDecode.rawValue)
                        }
                    }catch {
                        print(error)
                        errorHandler(NetworkResponse.unableToDecode.rawValue)
                    }
                case .failure(let networkFailureError):
                    errorHandler(networkFailureError.description)
                }
            }
        }
    }
    
    func regionStateEnter(clientID: String,
                          ruleID: String,
                          param: [String:Any],
                          completion: @escaping (_ jsonResponse: [String:Any]) -> (),
                          errorHandler:@escaping (_ error: String?) -> Void) {
        router.request(.regionStateEnter(clientID: clientID, ruleID: ruleID, param: param)) { data, response, error in
            if error != nil {
                print("NETWORK ERROR: Please check your network connection.")
                errorHandler(error?.localizedDescription)
            }
            
            if let response = response as? HTTPURLResponse {
                let result = self.handleNetworkResponse(response)
                switch result {
                case .success:
                    guard let responseData = data else {
                        errorHandler(NetworkResponse.noData.rawValue)
                        return
                    }
                    do {
                        let jsonData = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers) as? [String:Any]
                        print(jsonData ?? [:])
                        if let res = jsonData {
                            completion(res)
                        } else {
                            errorHandler(NetworkResponse.unableToDecode.rawValue)
                        }
                    }catch {
                        print(error)
                        errorHandler(NetworkResponse.unableToDecode.rawValue)
                    }
                case .failure(let networkFailureError):
                    errorHandler(networkFailureError.description)
                }
            }
        }
    }
    
    func regionStateExist(clientID: String,
                          ruleID: String,
                          param: [String:Any],
                          completion: @escaping (_ jsonResponse: [String:Any]) -> (),
                          errorHandler:@escaping (_ error: String?) -> Void) {
        router.request(.regionStateExit(clientID: clientID, ruleID: ruleID, param: param)) { data, response, error in
            if error != nil {
                print("NETWORK ERROR: Please check your network connection.")
                errorHandler(error?.localizedDescription)
            }
            
            if let response = response as? HTTPURLResponse {
                let result = self.handleNetworkResponse(response)
                switch result {
                case .success:
                    guard let responseData = data else {
                        errorHandler(NetworkResponse.noData.rawValue)
                        return
                    }
                    do {
                        let jsonData = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers) as? [String:Any]
                        print(jsonData ?? [:])
                        if let res = jsonData {
                            completion(res)
                        } else {
                            errorHandler(NetworkResponse.unableToDecode.rawValue)
                        }
                    }catch {
                        print(error)
                        errorHandler(NetworkResponse.unableToDecode.rawValue)
                    }
                case .failure(let networkFailureError):
                    errorHandler(networkFailureError.description)
                }
            }
        }
    }
    
    func updateLocation(clientID: String,
                        param: [String:Any],
                        completion: @escaping (_ jsonResponse: [String:Any]) -> (),
                        errorHandler:@escaping (_ error: String?) -> Void) {
        router.request(.updateLocation(clientID: clientID, param: param)) { data, response, error in
            if error != nil {
                print("NETWORK ERROR: Please check your network connection.")
                errorHandler(error?.localizedDescription)
            }
            
            if let response = response as? HTTPURLResponse {
                let result = self.handleNetworkResponse(response)
                switch result {
                case .success:
                    guard let responseData = data else {
                        errorHandler(NetworkResponse.noData.rawValue)
                        return
                    }
                    do {
                        let jsonData = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers) as? [String:Any]
                        print(jsonData ?? [:])
                        if let res = jsonData {
                            completion(res)
                        } else {
                            errorHandler(NetworkResponse.unableToDecode.rawValue)
                        }
                    }catch {
                        print(error)
                        errorHandler(NetworkResponse.unableToDecode.rawValue)
                    }
                case .failure(let networkFailureError):
                    errorHandler(networkFailureError.description)
                }
            }
        }
    }
    
    func beaconEnterState(clientID: String,
                          ruleID: String,
                          param: [String:Any],
                          completion: @escaping (_ jsonResponse: [String:Any]) -> (),
                          errorHandler:@escaping (_ error: String?) -> Void) {
        router.request(.beaconStateEnter(clientID: clientID, ruleID: ruleID, param: param)) { data, response, error in
            if error != nil {
                print("NETWORK ERROR: Please check your network connection.")
                errorHandler(error?.localizedDescription)
            }
            
            if let response = response as? HTTPURLResponse {
                let result = self.handleNetworkResponse(response)
                switch result {
                case .success:
                    guard let responseData = data else {
                        errorHandler(NetworkResponse.noData.rawValue)
                        return
                    }
                    do {
                        let jsonData = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers) as? [String:Any]
                        print(jsonData ?? [:])
                        if let res = jsonData {
                            completion(res)
                        } else {
                            errorHandler(NetworkResponse.unableToDecode.rawValue)
                        }
                    }catch {
                        print(error)
                        errorHandler(NetworkResponse.unableToDecode.rawValue)
                    }
                case .failure(let networkFailureError):
                    errorHandler(networkFailureError.description)
                }
            }
        }
    }
    
    func beaconExitState(clientID: String,
                          ruleID: String,
                          param: [String:Any],
                          completion: @escaping (_ jsonResponse: [String:Any]) -> (),
                          errorHandler:@escaping (_ error: String?) -> Void) {
        router.request(.beaconStateExit(clientID: clientID, ruleID: ruleID, param: param)) { data, response, error in
            if error != nil {
                print("NETWORK ERROR: Please check your network connection.")
                errorHandler(error?.localizedDescription)
            }
            
            if let response = response as? HTTPURLResponse {
                let result = self.handleNetworkResponse(response)
                switch result {
                case .success:
                    guard let responseData = data else {
                        errorHandler(NetworkResponse.noData.rawValue)
                        return
                    }
                    do {
                        let jsonData = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers) as? [String:Any]
                        print(jsonData ?? [:])
                        if let res = jsonData {
                            completion(res)
                        } else {
                            errorHandler(NetworkResponse.unableToDecode.rawValue)
                        }
                    }catch {
                        print(error)
                        errorHandler(NetworkResponse.unableToDecode.rawValue)
                    }
                case .failure(let networkFailureError):
                    errorHandler(networkFailureError.description)
                }
            }
        }
    }
    
    //MARK: Private Method
    
    fileprivate func handleNetworkResponse(_ response: HTTPURLResponse) -> Result<String>{
        switch response.statusCode {
        case 200...299: return .success
        case 401...500: return .failure(NetworkResponse.authenticationError.rawValue)
        case 501...599: return .failure(NetworkResponse.badRequest.rawValue)
        case 600: return .failure(NetworkResponse.outdated.rawValue)
        default: return .failure(NetworkResponse.failed.rawValue)
        }
    }
}
