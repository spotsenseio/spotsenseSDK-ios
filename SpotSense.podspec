
Pod::Spec.new do |s|

  s.name         = "SpotSense"
  s.version      = "1.0.2"
  s.summary      = "SpotSense is a web app and SDK for adding geofences to mobile apps"

  s.description  = <<-DESC "SpotSense enables mobile developers to add geofences to their mobile app through a web app, instead of rolling their own infrastructure, so they can focus on building killer apps instead of backend code."
                   DESC

  s.homepage     = "https://spotsense.io"



  s.license      = 'Apache License, Version 2.0'



  s.author             = { "spotsenseio" => "jonny@spotsense.io" }
  s.social_media_url = "https://twitter.com/spotsenseio"

  s.platform     = :ios, "10.0"
  s.swift_version = '4.2'


  s.source       = { :git => "https://github.com/spotsenseio/spotsenseSDK-ios.git", :tag => s.version }

	
  s.source_files  = "SpotSenseSDK/DispatchTimer.swift"
  s.source_files  = "SpotSenseSDK/Eddystone.swift"
  s.source_files  = "SpotSenseSDK/Rule.swift"
  s.source_files  = "SpotSenseSDK/SpotSense.swift"
  s.source_files  = "SpotSenseSDK/SpotSenseApp.swift"
  s.source_files  = "SpotSenseSDK/SpotSenseSDK.h"
  s.source_files  = "SpotSenseSDK/Info.plist"

  s.exclude_files = "Classes/Exclude"


  s.dependency 'Alamofire'
  s.dependency 'JWTDecode', '~> 2.1'
  s.dependency 'AsyncSwift'


end