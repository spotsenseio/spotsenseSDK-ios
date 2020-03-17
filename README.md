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

    txtLog = UITextView(frame: CGRect(x: 0, y: 0, width: 100, height: 10))
    txtLog.isScrollEnabled = true
    txtLog.textColor = UIColor.white
    txtLog.backgroundColor = UIColor.black
    txtLog.isEditable = false
    self.view.addSubview(txtLog)
    txtLog.translatesAutoresizingMaskIntoConstraints = false
    txtLog.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 0).isActive = true
    txtLog.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 55).isActive = true
    txtLog.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: 0).isActive = true
    txtLog.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -55).isActive = true
                    
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

    
     let logg = Logger()
     logg.log("App started")
            if let fileURL = logg.logFile {
           
                do{
                  self.txtLog.text = try String(contentsOf: fileURL, encoding: .utf8)
                }
                catch {/* error handling here */}
            }
    spotsense.delegate = self
}

 func ruleDidTrigger(response: NotifyResponse, ruleID: String) {
        
     if let segueID = response.segueID { // performs screenchange
                performSegue(withIdentifier: segueID, sender: nil)
            } else if (response.getActionType() == "http") {
                _ = response.getHTTPResponse()
            }
 }
 
 func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {

     spotsense.handleRegionState(region: region, state: .inside)
         
         let logg = Logger()
         
         if let fileURL = logg.logFile {
                        do {
                         self.txtLog.text = try String(contentsOf: fileURL, encoding: .utf8)
                        }
                        catch {/* error handling here */}
         }
     }
     
     func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
         
         spotsense.handleRegionState(region: region, state: .outside)

         let logg = Logger()
                logg.log("didExitRegion : \(region.identifier)")

                if let fileURL = logg.logFile {
                    //reading
                               do {
                                self.txtLog.text = try String(contentsOf: fileURL, encoding: .utf8)
                               }
                               catch {/* error handling here */}
                }
     }


 func didUpdateBeacon(beaconScanner: SpotSense, beaconInfo: BeaconInfo, data: NSDictionary) {
     
 }
 
 func didFindBeacon(beaconScanner: SpotSense, beaconInfo: BeaconInfo, data: NSDictionary) {

     NSLog("FIND: %@", beaconInfo.description)
     
     spotsense.handleBeaconEnterState(beaconScanner: beaconScanner, beaconInfo: beaconInfo, data: data)
     
     DispatchQueue.main.async {

          let logg = Logger()
               logg.log("FIND : \(beaconInfo.description)")
                       if let fileURL = logg.logFile {
               do {
                       self.txtLog.text = try String(contentsOf: fileURL, encoding: .utf8)
                       }
               catch {/* error handling here */}
                       }
     }
   
  }
  func didLoseBeacon(beaconScanner: SpotSense, beaconInfo: BeaconInfo, data: NSDictionary) {

     NSLog("LOST: %@", beaconInfo.description)
     
     spotsense.handleBeaconExitState(beaconScanner: beaconScanner, beaconInfo: beaconInfo, data: data)
     
     DispatchQueue.main.async {

     let logg = Logger()
     logg.log("LOST : \(beaconInfo.description)")
     if let fileURL = logg.logFile {
     do {
         self.txtLog.text = try String(contentsOf: fileURL, encoding: .utf8)
     }
     catch {/* error handling here */}
     }
         }

  }
  func didUpdateBeacon(beaconScanner: SpotSense, beaconInfo: BeaconInfo) {
    //NSLog("UPDATE: %@", beaconInfo.description)
  }
  func didObserveURLBeacon(beaconScanner: SpotSense, URL: NSURL, RSSI: Int) {
    //NSLog("URL SEEN: %@, RSSI: %d", URL, RSSI)
  }
  
  class Logger {

       var logFile: URL? {
          
          guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
          let formatter = DateFormatter()
          formatter.dateFormat = "dd-MM-yyyy"
          let dateString = formatter.string(from: Date())
          let fileName = "\(dateString).log"
          return documentsDirectory.appendingPathComponent(fileName)
      }

       func log(_ message: String) {
          guard let logFile = logFile else {
              return
          }

          let formatter = DateFormatter()
          formatter.dateFormat = "h:mm a"
          let timestamp = formatter.string(from: Date())
          guard let data = (timestamp + ": " + message + "\n").data(using: String.Encoding.utf8) else { return }

          if FileManager.default.fileExists(atPath: logFile.path) {
              if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                  fileHandle.seekToEndOfFile()
                  fileHandle.write(data)
                  fileHandle.closeFile()
              }
          } else {
              try? data.write(to: logFile, options: .atomicWrite)
          }
      }
  }
  extension UIViewController {

    func presentAlert(withTitle title: String, message : String) {
      let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
      let OKAction = UIAlertAction(title: "OK", style: .default) { action in
          print("You've pressed OK Button")
      }
      alertController.addAction(OKAction)
      self.present(alertController, animated: true, completion: nil)
    }
  }

```
4. Select your new app and create a rule in the SpotSense Dashboard
5. Test your rule out in the real world or in the iOS Simulator!

Have a question or got stuck? Let us know in the SpotSense Slack Community or shoot us an email (help@spotsense.io). We are happy to help!

