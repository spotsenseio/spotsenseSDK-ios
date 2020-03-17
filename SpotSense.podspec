

Pod::Spec.new do |s|

 
  s.name         = "SpotSense"
  s.version      = "1.0.1"
  s.summary      = "SpotSense is a web app and SDK for adding geofences to mobile apps"


  s.description  = <<-DESC "SpotSense enables mobile developers to add geofences to their mobile app through a web app, instead of rolling their own infrastructure, so they can focus on building killer apps instead of backend code."
                   DESC

  s.homepage     = "https://spotsense.io"



  s.license      = 'Apache License, Version 2.0'


  s.author             = { "spotsenseio" => "jonny@spotsense.io" }
  s.social_media_url = "https://twitter.com/spotsenseio"

  s.platform     = :ios, "10.0"
  s.swift_version = '4.0'


  s.source       = { :git => "https://github.com/spotsenseio/spotsenseSDK-ios.git", :tag => "#{s.version}" }


  # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  CocoaPods is smart about how it includes source code. For source files
  #  giving a folder will include any swift, h, m, mm, c & cpp files.
  #  For header files it will include any header in the folder.
  #  Not including the public_header_files will make all headers public.
  #


  # s.source_files  = 'SpotSenseSDK/*'
  s.source_files  = "SpotSenseSDK/*.{swift,plist,h}"
  s.exclude_files = "Classes/Exclude"

  # s.public_header_files = "SpotSenseSDK/**/*.h"


  # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  A list of resources included with the Pod. These are copied into the
  #  target bundle with a build phase script. Anything else will be cleaned.
  #  You can preserve files from being cleaned, please don't preserve
  #  non-essential files like tests, examples and documentation.
  #

  # s.resource  = "icon.png"
  # s.resources = "Resources/*.png"

  # s.preserve_paths = "FilesToSave", "MoreFilesToSave"


  # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Link your library with frameworks, or libraries. Libraries do not include
  #  the lib prefix of their name.
  #

  s.dependency 'Alamofire'
  s.dependency 'JWTDecode'

  # s.framework  = "SomeFramework"
  # s.frameworks = "SomeFramework", "AnotherFramework"

  # s.library   = "iconv"
  # s.libraries = "iconv", "xml2"


  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  If your library depends on compiler flags you can set them in the xcconfig hash
  #  where they will only apply to your library. If you depend on other Podspecs
  #  you can include multiple dependencies to ensure it works.

  # s.requires_arc = true

  # s.xcconfig = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2" }
  # s.dependency "JSONKit", "~> 1.4"

end