//
//  TokenAPI.swift
//  SpotSenseSDK
//
//  Created by Vibhor Jain on 06/09/23.
//  Copyright © 2023 SpotSense. All rights reserved.
//

import Foundation

public enum TokenAPI {
    case getToken(param: Parameters)
}

extension TokenAPI: EndPointType {
    
    var auth0URL: String { "https://spotsense.auth0.com/oauth/"
    }
    
    var baseURL: URL {
        guard let url = URL(string: auth0URL) else { fatalError("baseURL could not be configured.")}
        return url
    }
    
    var path: String {
        switch self {
        case .getToken:
            return "token"
        }
    }
    
    var httpMethod: HTTPMethod {
        return .post
    }
    
    var task: HTTPTask {
        switch self {
        case .getToken(let param):
            return .requestParameters(bodyParameters: param,
                                      bodyEncoding: .jsonEncoding,
                                      urlParameters: nil)
        }
    }
    
    var headers: HTTPHeaders? {
        return nil
    }
    
    
}
