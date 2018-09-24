//
//  SpotSenseApp.swift
//  sdkplayground
//
//  Copyright © 2018 SpotSense (Sonora Data, LLC). All rights reserved.
//

import Foundation

open class SpotSenseApp {
    public var appID:String
    public var appName: String
    
    public init (appID: String, appName: String) {
        self.appID = appID
        self.appName = appName
    }
}
