#  SpotSense SDK
## Requirements
* iOS 10+
* Swift 4.0+

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
        pod 'SpotSense', '~>0.1'
    end
    ```

    6. Run `pod install`

    7. Open your app's `.xcworkspace` file to launch Xcode
3. `import spotsense` and initialize SpotSense with Client ID and Secret from the Dashboard
```swift
import UIKit
import CoreLocation
import SpotSense

let spotsense = SpotSense(clientID: "client-id", clientSecret: "client-secret")
class ViewController: UIViewController, CLLocationManagerDelegate, SpotSenseDelegate {...}
```

4. Ask to use a user's location and add delegates to handle location updates
Note: Apple requires developers to add a description of why they are using a users location to Info.plist

```swift
let locationManager : CLLocationManager = CLLocationManager()
let notificationCenter = UNUserNotificationCenter.current()

override func viewDidLoad() {
    super.viewDidLoad()

    // get location permissions
    locationManager.requestAlwaysAuthorization()
    locationManager.delegate = self
    spotsense.delegate = self;

    if (CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse) {
        if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) { // Make sure region monitoring is supported.
            spotsense.getRules {}
        }
    }
}

func ruleDidTrigger(response: NotifyResponse, ruleID: String) { // delegate for handling rule triggers
    switch response.getActionType() {
    case "segue":
        if let segueID = response.segueID {
            performSegue(withIdentifier: segueID, sender: nil)
        }
    case "http":
        print("HTTP Response: (String(describing: response.getHTTPResponse()))")
    default:
        print("")
    }
}

func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) { // notify spotsense of geofence changes
    spotsense.handleRegionState(region: region, state: state)
}
```
4. Select your new app and create a rule in the SpotSense Dashboard
5. Test your rule out in the real world or in the iOS Simulator!

Have a question or got stuck? Let us know in the SpotSense Slack Community or shoot us an email (help@spotsense.io). We are happy to help!

