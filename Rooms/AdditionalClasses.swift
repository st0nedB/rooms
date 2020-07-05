//
//  AdditionalClasses.swift
//  Rooms
//
//  Created by Steffen Schieler on 23.05.20.
//  Copyright © 2020 Steffen Schieler. All rights reserved.
//

import UIKit
import CoreLocation
import CoreML

class beaconData {
    /*
    This class is to be used in the prediction and data collection step to ensure equal data characteristics and hence improve stability, accuracy and reliability of the app.
    */
    let beaconDict:[String:Int]
    let defaultRSSI:Double = -100
    var numBeacons:Int = 0
    
    // self init
    init(beaconDict: [String:Int]){
        self.beaconDict = beaconDict
        self.numBeacons = beaconDict.count
    }
    
    func processBeaconMeasurement(beaconMeasurement: [CLBeacon]) -> ( [Double], Int ) {
        /*
        Function that processes the beacon measurements.
        It extracts the RSSI from the measurements and returns an array in which the RSSI measurements are ordered in accordance with the row indices specified in the beaconDict.
        If a beacon is not present in the measurement, the default value in defaultRSSI is used.
        The size is always Nx1, where N is the number of beacons specified in beaconDict.
        */
        
        // initialize some variables
        var array: [Double] = Array(repeating: 1, count: numBeacons)                        // array of numBeacons x singleBeaconMeasurement, 1 means the beacon is invisible (normalized with -100)
        var numSawBeacons: Int = 0                                                          // number of Beacons visible in the last measurement
        var beaconIdx: Int                                                                  // value in the beaconDict
        // iterate over the found beacons and obtain RSSI
        for ( _, beacon) in beaconMeasurement.enumerated(){
            beaconIdx = beaconDict[String(Int(truncating: beacon.minor))]!                          // row indice for the beacon the measurementArray
            if beacon.rssi != 0 {
                array[beaconIdx] = Double(beacon.rssi) / defaultRSSI                        // write RSSI into the measurementArray
            } else {
                array[beaconIdx] = Double(1)                                                // if a beacon is invisible, it is sometimes reported with 0 RSSI
                numSawBeacons -= 1                                                          // ensure the beacon isn't counted as visible then
            }
            numSawBeacons += 1                                                              // increment number of beacons in the report
        }
        
        // return the measurement array
        return (array, numSawBeacons)
    }
    
    func convertToMLMultiArray(array: [Double]) -> MLMultiArray {
        /*
        Takes as input an array of Double values (e.g. the output of 'func processBeaconMeasurement'), and returns an MLMultiArray that can be fed to the ML Model for prediction.
        */
        let numValues = NSNumber(value: 1*numBeacons)
        let mlArray = try? MLMultiArray(shape: [numValues], dataType: MLMultiArrayDataType.float32)
        let reduced = array
        
        for i in 0..<reduced.count {
            mlArray?[i] = NSNumber(value: reduced[i])
        }

        return mlArray!
    }
}

class trainingDataFiles {
    /*
    This class is used to manage the training data recorded and stored by the app.
    It provides file search, inspection, management, and sharing methods.
    The recorded data is stored in JSON format in the main directory of the app.
    This class is initialized without variables.
    */
    
    // write array to json file
    func tojson(object: [[Double]], filename: String) {
        /*
        Takes the 2D Array in object and dumps it to a json file with the filename specified in filename.
        One file is created for each room. Should overwrite if file already exists.
        */
        let pathDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager().createDirectory(at: pathDirectory, withIntermediateDirectories: true)
        let filepath = pathDirectory.appendingPathComponent(filename)
        let json = try? JSONEncoder().encode(object)
        // try to write the array to a json file
        do {
            try json!.write(to: filepath)
        } catch {
            print("Failed to write JSON data: \(error.localizedDescription)")
        }
    }
     
    // read the files in the default directory
    func readFiles(suffix:String) -> Array<URL> {
        /*
        Reads all files with the .json suffix in the apps main directory and returns their URLs in an array.
        */
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var fileURLs:Array<URL> = Array()
        do {
            fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            // process files
            fileURLs = fileURLs.filter{ $0.pathExtension == suffix }
        } catch {
            print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
        }
        return fileURLs
    }
     
    // check if a file for each room is available
    func checkDataAvailable(rooms: [String]) -> (fileURLs:Array<URL>, path:String, allAvailable:Bool ) {
        /*
         Checks if a data file for each room is available. Returns an empty array otherwise.
         */
        let fileURLs = readFiles(suffix: "json")
        var files:Array<String> = Array()
        var file:String
        var path:String = String()
        var allAvailable:Bool

        if !fileURLs.isEmpty {
            path = fileURLs[0].path
        }

        for url in fileURLs {
           file = url.lastPathComponent.components(separatedBy: ".")[0]
           files.append(file)
        }

        if files.containsSameElements(as: rooms) {
           allAvailable = true
        } else {
            allAvailable = false
        }

        return ( fileURLs, path, allAvailable )
    }
}

/*
class appConfig {
    public struct configuration: Codable {
        // Room settings
        var rooms: [String]

        // Beacon Settings
        var beaconUUID: UUID
        var beaconMajor: CLBeaconMajorValue
        var beaconDict: [ Int:Int ]
        var minorIDs: [ Int ]

        // MQTT Settings
        var mqttIP:String
        var mqttPort:UInt16
        var mqttUser:String
        var mqttPassword:String
        var mqttTopic:String
        
        // Model Settings
        var modelURL:String
        
        // Other Settings
        var numSamples: Int
        
    }
    
    public func readConfigValue(key: String) -> (Any){
        /*
        Read a value for a given key.
        */
        let config = readJsonConfig()

        return config![key] as Any
    }
    
    public func saveConfigValue(key: String, value: Any) -> (Void){
        /*
        Add a value for a given key to the config.
        */
        var config = readJsonConfig()
        
        do {
            config![key] = value
            writeJsonConfig(object: config!)
        } catch {
            NSError("Could not write JSON File!")
        }
    }
    
    public func exportConfig() -> (Void){
        /*
        Export current JSON config file.
        */
        
    }
    
    public func importConfig() -> (Void){
        /*
        Import JSON config file. Must be named "config.json".
        */
    }
    
    private func readJsonConfig() -> ([String: Any])? {
        /*
        Reads the Json config file and return it as an object
        */
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            // process files
            let file = fileURLs.filter{ $0.lastPathComponent == "config.json" }
            if !file.isEmpty {
                let data = try Data(contentsOf: file[0], options: .mappedIfSafe)
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                  // appropriate error handling
                    fatalError("Error reading config json file.")
                  return nil
                }
                return (json)
            } else {
                return nil
            }
        } catch {
            fatalError("Error while checking and reading of measurement file.")
        }
    }
    
    private func writeJsonConfig(object: [String: Any]) -> (Void){
        /*
        Write the config to a JSOn file
        */
        let filename = "config.json"
        let pathDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager().createDirectory(at: pathDirectory, withIntermediateDirectories: true)
        let filepath = pathDirectory.appendingPathComponent(filename)
        let json = try? JSONEncoder().encode(object as! [String: String])
        // try to write the array to a json file
        do {
            try json!.write(to: filepath)
        } catch {
            print("Failed to write JSON data: \(error.localizedDescription)")
        }
    }
}
*/


extension Array where Element: Comparable {
    /*
    This extension is used to compare two arrays and gives true if they contain the same elememts regardless of their order.
    */
    func containsSameElements(as other: [Element]) -> Bool {
        return self.count == other.count && self.sorted() == other.sorted()
    }
}


public class RoomsMlModelInput : MLFeatureProvider {
    /*
    see here for details: http://hadiajalil.com/coreml-compilingmodel/
    */

    // Input image in the format of CVPixelBuffer
    public var dense_1_input_output: MLMultiArray

    // Input feature name
    public var featureNames: Set<String> {
        get {
            return ["dense_1_input_output"]
    }
    }

    // Value for a certain input feature.
    public func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "dense_1_input_output") {
            return MLFeatureValue(multiArray: dense_1_input_output)
        }
        return nil
    }

    public init(dense_1_input_output: MLMultiArray) {
        self.dense_1_input_output = dense_1_input_output
    }
}
