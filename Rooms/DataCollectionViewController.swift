//
//  DataColelctionViewController.swift
//  Rooms
//
//  Created by Steffen Schieler on 01.05.20.
//  Copyright © 2020 Steffen Schieler. All rights reserved.
//

import UIKit
import CoreLocation
import CoreML

class DataCollectionViewController: UIViewController, CLLocationManagerDelegate {
    // load user-defaults
    let defaults = UserDefaults.standard
    
    // connect to data from other viewControllers
    var rooms:[String] = [String()]    // list of rooms, as configured in Userdefaults
    var numSamples:Int = 0             // number of samples to collect, as configured in SettingsViewController
    var beaconDict:[String:Int] = [:]
    
    // Variables
    var numBeacons:Int = 0                                          // number of beacons, will be updated when view is loaded
    var room:String = String()                                      // string, which specifies the current room
    
    // Location measurement related variables
    var beaconParser:beaconData = beaconData(beaconDict: [:])
    var dataFiles = trainingDataFiles()
    let locationManager:CLLocationManager = CLLocationManager()     // location Manager instance
    var measurements:[[Double]] = [[]]                              // measurement array
    
    // Define a beacon region
    var uuid:UUID = UUID(uuidString: "db50b706-f209-4acd-b55d-427289535c8d")!
    var major:CLBeaconMajorValue = CLBeaconMajorValue(0)
    
    // other requires variables
    var iterCounter:Int = 0                                         // iteration Counter for measurements
    var progress = Progress()                                       // the progress view bar
    
    // IBOutlets
    @IBOutlet weak var sampleCounter: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var activityView: UIActivityIndicatorView!
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var recordingButton: UIButton!
    @IBOutlet weak var labelSelectedRoom: UILabel!
    @IBOutlet weak var buttonSelectRoom: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // load or update the global settings variables
        rooms = defaults.object(forKey: "rooms") as? [String] ?? [String()]
        numSamples = defaults.integer(forKey: "numCollectSamples")
        beaconDict = defaults.object(forKey: "beaconDict") as! [ String:Int ]
        numBeacons = beaconDict.count
        beaconParser = beaconData(beaconDict: beaconDict)
        
        // Setup the Location Manager delegate
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
        // Update/Create the beacon region
        uuid = UUID(uuidString: defaults.string(forKey: "beaconUUID")!)!
        major = CLBeaconMajorValue(defaults.integer(forKey: "beaconMajor"))
            
        // check if a room is selected
        if room.isEmpty {
            recordingButton.isEnabled = false
        }
        
        // make the activityView invisible
        activityView.isHidden = true
        
        // set the progress bar to zero
        self.progress = Progress(totalUnitCount: Int64(numSamples))  // the 10 should equal the number of numSamples
        self.progress.completedUnitCount = 0
        self.progressView.setProgress(Float(self.progress.fractionCompleted), animated: true)
    
        // empty the sample counter label
        sampleCounter.text = String()
        
        print(rooms)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewDidLoad()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "getDataSegue" {
            let selectRoomVC: SelectRoomsViewController = segue.destination as! SelectRoomsViewController
            selectRoomVC.RoomDelegate = self
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying: CLBeaconIdentityConstraint) {
        /*
        This is called by the Location Manager, when new measurements are available
        */
        
        // parse the measurement into an array to append to the larger measurementArray
        let singleMeasurement = beaconParser.processBeaconMeasurement(beaconMeasurement: beacons)
        
        // append to the larger array of multiple measurements
        measurements[iterCounter] = singleMeasurement.0
        
        // increment IterationCounter
        iterCounter += 1
        
        // update SampleCounter label text
        sampleCounter.text = String(iterCounter) + "/" + String(numSamples) + ", saw \(singleMeasurement.1) Beacons"
        
        // update progressbar
        self.progress.completedUnitCount += 1
        self.progressView.setProgress(Float(self.progress.fractionCompleted), animated: true)
        
        // if enough samples have been collected, stop the ranging
        if iterCounter >= numSamples {
            stopRecording()
            dataFiles.tojson(object: measurements, filename: room + ".json") // write results to json file
        }
    }
    
    
    func startRecording( room: String) {
        /*
        Start the logging of Beacon values for the specified region
        */
        
        // set the iteration counter to zero
        iterCounter = 0
        
        // create an empty measurement array
        measurements = Array(repeating: Array(repeating: beaconParser.defaultRSSI, count: numBeacons), count: numSamples )
        
        // update the UI elements
        exportButton.isEnabled = false
        activityView.isHidden = false
        activityView.startAnimating()
        progressView.progress = 0.0
        progress.completedUnitCount = 0
        sampleCounter.text = String(0)
        
        // start the beacon ranging
        locationManager.startRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: uuid, major: major))
    }
    
    // stop Beacon logging
    func stopRecording(){
        /*
        Stops the logging of Beacon values for a specific beacon region.
        */
        
        // stop the beacon measurements
        locationManager.stopRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: uuid, major: major))
        
        // save the result to a json file
        dataFiles.tojson(object: measurements, filename: room)
        
        // Update UI Elements
        activityView.stopAnimating()
        activityView.isHidden = true
        recordingButton.isEnabled = true
        exportButton.isEnabled = true
        buttonSelectRoom.isEnabled = true
    }
    
    /*
    ---------------------------------
    IBOutlets from the ViewController
    ---------------------------------
    */
    
    @IBAction func startRecordingButton(_ sender: UIButton) {
        /*
        Button to start recording data.
        */
        buttonSelectRoom.isEnabled = false
        recordingButton.isEnabled = false
        exportButton.isEnabled = false
        labelSelectedRoom.text = room
        startRecording(room: room)
    }
    
    @IBAction func exportData(_ sender: UIButton) {
        /*
        Export the available json Data in the apps main directory
        */
        var files:[URL]
        var allAvailable:Bool
        (files, _, allAvailable) = dataFiles.checkDataAvailable(rooms: rooms)
        /* TODO: Add an option to remove already existing json files when a room is deleted in the Settings>Rooms Viewcontroller. Otherwise this check will prohibit export of files!
        if !allAvailable {
            let alert = UIAlertController(title: "Missing Files!", message: "For some rooms no data has been recorded. They will not be part of the prediction.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
            NSLog("Incomplete Room alert.")
            }))
            self.present(alert, animated: true, completion: nil)
        }
        */
        let activityViewController = UIActivityViewController(activityItems: files, applicationActivities: nil)
        self.present(activityViewController, animated: true, completion: nil)
    }
}

extension DataCollectionViewController: SelectRoomDelegate {
    /*
    This extension is used to pass data between the SelectRoomViewController and the DataCollectionViewController
    */
    func UpdateSelectedRoom(selectedRoom: String) {
        room = selectedRoom
        labelSelectedRoom.text = "\(room) selected"
        recordingButton.isEnabled = true
    }
}
