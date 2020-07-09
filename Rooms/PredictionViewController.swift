//
//  PredictionViewController.swift
//  Rooms
//
//  Created by Steffen Schieler on 01.05.20.
//  Copyright © 2020 Steffen Schieler. All rights reserved.
//

import UIKit
import CoreML
import CoreLocation
import Moscapsule
import CoreMotion

class PredictionViewController: UIViewController, CLLocationManagerDelegate {

    let defaults = UserDefaults.standard
    
    // get the model
    var model = MLModel()
    var modelValid = false
    var currentRoom:String = ""
    var predictionThreshold = 0.7
    
    // Variables
    var numBeacons:Int = 0                               // number of beacons, will be updated when view is loaded
    
    // Location measurement related variables
    var beaconDict:[String:Int] = [:]
    var beaconParser:beaconData = beaconData(beaconDict: [:])
    var locationManager:CLLocationManager = CLLocationManager()     // location Manager instance
    var beaconRaningState:Int = 1 // 1 = ranging, 2 = paused, 3 = stopped
    
    // Define a beacon region
    var uuid:UUID = UUID(uuidString: "db50b706-f209-4acd-b55d-427289535c8d")!
    var major:CLBeaconMajorValue = CLBeaconMajorValue(0)
    
    // mqtt-Config
    var mqttConfig:MQTTConfig = MQTTConfig(
        clientId: "user",
        host: "locahost",
        port: 1883,
        keepAlive: 5
    )
    
    // CoreMotion and MotionArray
    let motionManager = CMMotionManager()
    var accelerationVector:[Double] = [ 0, 0 ]    // used to store the last two measurements from the accelerometer
    var wasMovingUntil:Date = Date()  // used to indicate the last time the device moved
    let accelerationThreshold = 0.1  // threshold for the acceleration at which the prediction is started in [m/s^2]
    let timeGrace = TimeInterval(5) // grace before the prediction is stopped after moving
    var fakeMove = false  // this variable indicates a fake move, it will only start location updates, but not beacon ranging
    
    // Background Task
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // IBOutlets
    @IBOutlet weak var labelPredictionLikelyhood: UILabel!
    @IBOutlet weak var labelRoom: UILabel!
    @IBOutlet weak var togglePrediction: UISegmentedControl!
    @IBOutlet weak var isRangingBeaconsIndicator: UIActivityIndicatorView!
    @IBOutlet weak var thresholdSlider: UISlider!
    @IBOutlet weak var predictionThresholdLabel: UILabel!
    @IBOutlet weak var predictionThresholdSliderMaxLabel: UILabel!
    @IBOutlet weak var predictionThresholdSliderMinLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // setup the slider
        thresholdSlider.minimumValue = 0.5
        thresholdSlider.maximumValue = 1.0
        thresholdSlider.isContinuous = true
        predictionThresholdLabel.text = "Prediction Threshold (\(predictionThreshold*100) %)"
        thresholdSlider.value = Float(predictionThreshold)
        // disable for now, I dont like the looks
        thresholdSlider.isHidden = true
        predictionThresholdLabel.isHidden = true
        predictionThresholdSliderMaxLabel.isHidden = true
        predictionThresholdSliderMinLabel.isHidden = true
        
        // enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // initialize the ml model
        let fileManager = FileManager.default
        let documentsURL = try! fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let modelURL = documentsURL.appendingPathComponent(ModelSettingsViewController.modelName)
        
        if !fileManager.fileExists(atPath: modelURL.path) {
            labelPredictionLikelyhood.text = "Configure one in the settings."
            labelRoom.text = "No model!"
            return
        }
        
        // check if we can compile the model -> Error Code 1
        guard let compiledModelURL = try? MLModel.compileModel(at: modelURL) else {
            labelRoom.text = "Model Error."
            labelPredictionLikelyhood.text = "Please Re-Generate Model! (Code 1)"
            togglePrediction.selectedSegmentIndex = 1
            return
        }
        
        // check if the model can be used as MLModel -> Error Code 2
        do {
            model = try MLModel(contentsOf: compiledModelURL)
        } catch {
            labelRoom.text = "Model Error."
            labelPredictionLikelyhood.text = "Please Re-Generate Model! (Code 2)"
            togglePrediction.selectedSegmentIndex = 1
            return
        }
        
        // we now have a valid model, set the variable so we can easily check it at other occurences
        modelValid = true
        
        // load or update the global settings variables
        beaconDict = defaults.object(forKey: "beaconDict") as! [String:Int]
        numBeacons = beaconDict.count
        beaconParser = beaconData(beaconDict: beaconDict)
        
        // Setup the Location Manager delegate
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.authorizationStatus() != .authorizedAlways {
            // add a UI info to show that background monitoring is not enabled
            print(CLLocationManager.authorizationStatus())
        }
        
        // this ensures the ranging works properly in background
        locationManager.allowsBackgroundLocationUpdates = true  // enables the background ranging
        locationManager.pausesLocationUpdatesAutomatically = true  // enables automatic pausing of ranging to save power
        locationManager.startMonitoring(for: CLBeaconRegion(beaconIdentityConstraint: CLBeaconIdentityConstraint(uuid: uuid, major: major), identifier: ""))
        
        // Update/Create the beacon region
        uuid = UUID(uuidString: defaults.string(forKey: "beaconUUID")!)!
        major = CLBeaconMajorValue(defaults.integer(forKey: "beaconMajor"))
        
        // Setup the MQTT connection
        let mqttConfig = MQTTConfig(
            clientId: defaults.string(forKey: "MQTTUsername")!,
            host: defaults.string(forKey: "MQTTIP")!,
            port: Int32(defaults.integer(forKey: "MQTTPort")),
            keepAlive: 5
        )
        
        mqttConfig.mqttAuthOpts = MQTTAuthOpts(
            username: defaults.string(forKey: "MQTTUsername")!,
            password: defaults.string(forKey: "MQTTPassword")!
        )
        
        // setup the motion manager
        motionManager.deviceMotionUpdateInterval = 0.5
        motionManager.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler: userMotionHandler(data:error:))
        
        // start the ranging
        startPrediction()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewDidLoad()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(true)
        stopPrediction()
    }
    
    // This function is called by the LocationManager when new measurements are available
    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying: CLBeaconIdentityConstraint) {
        
        //
        //print("CLLocMan Delegate Triggered!", Date())
        // parse the beacon measurement into an array
        let singleMeasurement = beaconParser.processBeaconMeasurement(beaconMeasurement: beacons)
        
        // convert to an MLMultiArray
        let mlModelInput = beaconParser.convertToMLMultiArray(array: singleMeasurement.0)
        
        // the prediction with the model can fail due to invalid settings, i.e. when the settings were updated, but not the model
        do {
            print("0")
            // attempt to make a prediction
            let output = try model.prediction(from: RoomsMlModelInput(dense_1_input_output: mlModelInput))
            print("1")
            // get the predictions label
            let predRoom = String(output.featureValue(for: "classLabel")!.stringValue)
            
            print("2")
            // calculate the prediction accuracy rounded to one decimal place
            let predProb = round( Double( truncating: output.featureValue(for: "output1")!.dictionaryValue[AnyHashable(predRoom)]! )*1000)/10
            
            // if the prediction probability exceeds a threshold, accept the prediction
            print("3")
            if predProb > predictionThreshold*100 && currentRoom != String(predRoom) && !fakeMove {
                // update currentRoom
                print("4")
                currentRoom = String(predRoom)
                print(currentRoom)
                
                // Update the UI Elements
                labelRoom.text = currentRoom
                labelPredictionLikelyhood.text = String(format: "%.2f %%", arguments: [predProb])
                    
                print("5")
                // send to mqtt broker
                let json = ["room" : predRoom, "likelyhood": predProb] as [String : Any]
                print("6")
                publishToMQTTServer(mqttConfig: mqttConfig, message: json)
            }
        } catch {
            stopPrediction(labelRoomText: "Invalid Model!", labelPredictionLikelyhoodtext:  "Please update in Settings.")
        }
    }
    
    // start prediction if the device enters the region
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        startPrediction()
        let json = ["room" : "Home", "likelyhood": 100] as [String : Any]
        publishToMQTTServer(mqttConfig: mqttConfig, message: json)
    }
    
    // stop prediction if the device leaves the region
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        stopPrediction()
        let json = ["room" : "Away", "likelyhood": 100] as [String : Any]
        publishToMQTTServer(mqttConfig: mqttConfig, message: json)
    }
    
    func userMotionHandler( data: CMDeviceMotion?, error: Error? ) -> Void {
        /*
        This function monitors the user-acceleration
        */
        fakeMove = false
        let absAcceleration = round(vectorMagnitude(array: [ data!.userAcceleration.x, data!.userAcceleration.y, data!.userAcceleration.z ])*1e4)/1e4
        accelerationVector[0] = accelerationVector[1]
        accelerationVector[1] = absAcceleration
        
        let avgAcceleration = average(array: accelerationVector)
        
        if avgAcceleration >= accelerationThreshold {
            wasMovingUntil = Date()
        }
        
        // if this update happens as a background-task, check the remaining time. If it is < 10s (good value??), start resume the beacon ranging
        switch UIApplication.shared.applicationState {
         case .active:
            // if it is in the foreground
            break
         case .background:
            // if executed in the backgorund
            let remainingTime = UIApplication.shared.backgroundTimeRemaining
            if remainingTime < 1 {
                // pretend the device moved, to trigger background beacon ranging
                print("Making Fake Move.")
                wasMovingUntil = Date()
                fakeMove = true
            }
         case .inactive:
            break
        @unknown default:
            break
        }
        
        // update the beacon ranging state
        updateBeaconRangingState()
    }
    
    func updateBeaconRangingState() {
        /*
        This function controls the beacon ranging state, depending on some properties
        */
        // verify the battery level is above 0.2 (20%)
        var batteryLevel: Float { UIDevice.current.batteryLevel }
        if batteryLevel < 0.3 && UIDevice.current.batteryState != .charging {
            stopPrediction()
            labelPredictionLikelyhood.text = "Due to low battery. (< 30%)"
        } else {
            // is currently ranging beacons
            if beaconRaningState == 1 {
                if Date() > wasMovingUntil + timeGrace && UIApplication.shared.applicationState == .background {
                    // pause the prediction as device is not moving
                    pausePrediction()
                } else if togglePrediction.selectedSegmentIndex == 1 {
                    // stop the prediction from user input
                    stopPrediction()
                }
            // beacon ranging is paused
            } else if beaconRaningState == 2 {
                if togglePrediction.selectedSegmentIndex == 1 {
                    // stop the prediction from user input
                    stopPrediction()
                } else if Date() < wasMovingUntil + timeGrace {
                    // start prediction as the device has moved, wasMovingUntil has changed
                    startPrediction()
                }
            // beacon ranging is stopped
            } else if beaconRaningState == 3 {
                if togglePrediction.selectedSegmentIndex == 0 {
                    startPrediction()
                }
            } else {
                print("Invalid State of beaconRangingState")
            }
        }
    }
    
    func startPrediction() {
        /*
        Start/Resume the monitoring beacons in the specified region. This also starts the prediction of rooms.
        */
        locationManager.startRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: uuid, major: major))
        
        // if always position is authorized, use it
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            locationManager.startUpdatingLocation()
            beaconRaningState = 1
        }
        
        // end the background task, if there is one
        if backgroundTask != .invalid {
            endBackgroundTask()
        }
        
        // update UI Elements
        isRangingBeaconsIndicator.isHidden = false
        isRangingBeaconsIndicator.startAnimating()
        labelRoom.text = "Starting..."
        togglePrediction.selectedSegmentIndex = 0
    }
    
    func stopPrediction(labelRoomText:String? = nil, labelPredictionLikelyhoodtext:String? = nil) {
        /*
        Stop the monitoring beacons in the specified region.
        */
        locationManager.stopRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: uuid, major: major))
        // if always position is authorized, disable it
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            locationManager.stopUpdatingLocation()
            beaconRaningState = 3
        }
        
        // end the background task
        if backgroundTask != .invalid {
            endBackgroundTask()
        }
        
        // Update UI Elements
        labelRoom.text = labelRoomText ?? "Prediction stopped."
        labelPredictionLikelyhood.text = labelPredictionLikelyhoodtext ?? ""
        isRangingBeaconsIndicator.isHidden = true
        isRangingBeaconsIndicator.stopAnimating()
        togglePrediction.selectedSegmentIndex = 1
    }
    
    func pausePrediction() {
        /*
        This function pauses the beacon-ranging if the device does not move. It does not change the prediction label, but add an idle indicator.
        */
        locationManager.stopRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: uuid, major: major))
        // if always position is authorized, disable it
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            locationManager.stopUpdatingLocation()
            beaconRaningState = 2
        }
        
        // register the background task
        registerBackgroundTask()
        
        // Update UI Elements
        isRangingBeaconsIndicator.isHidden = false
        isRangingBeaconsIndicator.stopAnimating()
        
    }
    
    func publishToMQTTServer(mqttConfig: MQTTConfig, message: [String:Any]) {

        // setup the data object
        let data = try! JSONSerialization.data(withJSONObject: message, options: .prettyPrinted)
        
        // create new MQTT Connection
        let mqttClient = MQTT.newConnection(mqttConfig, connectImmediately: true)
        mqttClient.publish(
            data,
            topic: defaults.string(forKey: "MQTTTopic") ?? "rooms/",
            qos: 0,
            retain: true
        )

        // disconnect
        mqttClient.disconnect()
    }
    
    /*
    ---------------------------------
    IBOutlets from the ViewController
    ---------------------------------
    */
    @IBAction func togglePrediction(_ sender: Any) {
        if !modelValid {
            // if we have no valid model file
            togglePrediction.selectedSegmentIndex = 1
        }
        
        updateBeaconRangingState()
    }
    
    @IBAction func updatePredictionThreshold(_ sender: Any) {
        predictionThreshold = Double(round(thresholdSlider.value*100)/100)
        predictionThresholdLabel.text = "Prediction Threshold (\(round(predictionThreshold*100)) %)"
    }
    
    /*
    ---------------------------------
    Private math functions, cause I don't understand Swift sometimes
    ---------------------------------
    */
    func vectorMagnitude(array:[Double]) -> (Double) {
        /*
        Returns an element-wise squared version of the input array
        */
        return sqrt(array.map({ Double(pow(Double($0), 2.0)) }).reduce(0, +))
    }
    
    func average(array:[Double]) -> (Double) {
        /*
        Returns the average of the input array
        */
        return array.reduce(0, +) / Double(array.count)
    }
}

// Extension for Background Processing
extension PredictionViewController {
    func registerBackgroundTask() {
        print("Background task registered")
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
        self?.endBackgroundTask()
        }
        assert(backgroundTask != .invalid)
    }
      
    func endBackgroundTask() {
        /*
        Call this function ones the Background processing is finished. So probably never, in our case.
         */
        print("Background task ended.")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
}
