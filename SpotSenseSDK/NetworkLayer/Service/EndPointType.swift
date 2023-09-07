//
//  EndPoint.swift
//  SpotSenseSDK
//
//  Created by Samyak Jain on 06/09/23.
//  Copyright © 2023 SpotSense. All rights reserved.
//

import Foundation

protocol EndPointType {
    var baseURL: URL { get }
    var path: String { get }
    var httpMethod: HTTPMethod { get }
    var task: HTTPTask { get }
    var headers: HTTPHeaders? { get }
}

