#  SpotSense SDK
## Requirements
* iOS 10+
* Swift 4.2+

## Getting Started
### Create an App
1. Create an app in the [SpotSense Dashboard](http://dashboard.spotsense.io)
2. Download the SpotSense SDK
    Download the SpotSenseSDK via GitHub or CocoaPods by doing the following

    1. Create an XCode Project

    2. In Terminal, navigate to the Xcode project directory

    3. Create a PodFile by running `pod init`

    4. Open PodFile in Xcode or a Text Editor

    5. Add the following code to your PodFile:
    ```
    target 'your-app' do
        # Pods for your-app
        pod 'SpotSense', '~>1.0.2'
    end
    ```

    6. Run `pod install`

    7. Open your app's `.xcworkspace` file to launch Xcode
3. `import spotsense` and initialize SpotSense with Client ID and Secret from the Dashboard
```swift
import UIKit
import SpotSense
import CoreLocation
import UserNotifications

let notificationCenter = UNUserNotificationCenter.current()

let spotsense = SpotSense(clientID: "client-id", clientSecret: "client-secret")

class ViewController: UIViewController, CLLocationManagerDelegate, SpotSenseDelegate {...}
```

4. Ask to use a user's location and add delegates to handle location updates
Note: Apple requires developers to add a description of why they are using a users location to Info.plist

```swift
let locationManager : CLLocationManager = CLLocationManager()

override func viewDidLoad() {
    super.viewDidLoad()

    // get notification permission, only required if sending notifications with SpotSense
    notificationCenter.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
        spotsense.notificationStatus(enabled: granted);
        }
            // get location permissions
            locationManager.delegate = self
            locationManager.activityType = .automotiveNavigation
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = 5.0
            locationManager.requestAlwaysAuthorization()
            locationManager.startUpdatingLocation()
            spotsense.delegate = self; // attach spotsense delegate to self
            
    if (CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse) {
        if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) { // Make sure region monitoring is supported.
      
        }
    }
    spotsense.delegate = self; // attach spotsense delegate to self

}

 func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {

     //Will Notify Enter event to dashboard for specific region
     spotsense.handleRegionState(region: region, state: .inside)
 }
     
 func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
     
     //Will Notify Exit event to dashboard for specific region
     spotsense.handleRegionState(region: region, state: .outside)
 }
 
 func didFindBeacon(beaconScanner: SpotSense, beaconInfo: BeaconInfo, data: NSDictionary) {
     
     //Will Notify Enter event to dashboard for specific beacon
     spotsense.handleBeaconEnterState(beaconScanner: beaconScanner, beaconInfo: beaconInfo, data: data)
  }
 
 func didLoseBeacon(beaconScanner: SpotSense, beaconInfo: BeaconInfo, data: NSDictionary) {
     
      //Will Notify Exit event to dashboard for specific beacon
     spotsense.handleBeaconExitState(beaconScanner: beaconScanner, beaconInfo: beaconInfo, data: data)
  }
 
 func ruleDidTrigger(response: NotifyResponse, ruleID: String) {
     
 }
 
 func didUpdateBeacon(beaconScanner: SpotSense, beaconInfo: BeaconInfo, data: NSDictionary) {
     
 }
 
 func didObserveURLBeacon(beaconScanner: SpotSense, URL: NSURL, RSSI: Int) {
     
 }
  
```
4. Select your new app and create a rule in the SpotSense Dashboard
5. Test your rule out in the real world or in the iOS Simulator!

Have a question or got stuck? Let us know in the SpotSense Slack Community or shoot us an email (help@spotsense.io). We are happy to help!

