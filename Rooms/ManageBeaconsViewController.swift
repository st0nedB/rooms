//
//  ManageBeaconMinorIDViewController.swift
//  Rooms
//
//  Created by Steffen Schieler on 09.05.20.
//  Copyright © 2020 Steffen Schieler. All rights reserved.
//

import UIKit

class ManageBeaconsViewController: UIViewController, UITextFieldDelegate {
    
    let defaults = UserDefaults.standard
    
    var beaconUUID: UUID = UUID(uuidString: "db50b706-f209-4acd-b55d-427289535c8d")!
    var beaconMajor: Int = 0
    var beaconMinors: [ Int ] = [ ]
    var beaconDict:[ String:Int ] = [:]
    
    
    @IBOutlet weak var minorIDTable: UITableView!
    @IBOutlet weak var addMinorIDTextField: UITextField!
    @IBOutlet weak var beaconUUIDTextField: UITextField!
    @IBOutlet weak var beaconMajorIDTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // load user defaults
        beaconUUID = UUID(uuidString: defaults.string(forKey: "beaconUUID") ?? "db50b706-f209-4acd-b55d-427289535c8d")!
        beaconMajor = defaults.integer(forKey: "beaconMajor")
        beaconMinors = defaults.object(forKey: "beaconMinors") as? [Int] ?? [0]
        
        // Minor ID Table
        minorIDTable.delegate = self
        minorIDTable.dataSource = self
        minorIDTable.tableFooterView = UIView(frame: CGRect.zero)
        
        // change the labels to the defaults
        beaconUUIDTextField.text = beaconUUID.uuidString
        beaconMajorIDTextField.text = String(beaconMajor)
        
        // get the current beaconDict
        beaconDict = makeBeaconDict(beacons: beaconMinors)
    }
    

    @IBAction func setUUIDButton(_ sender: Any) {
        beaconUUID = UUID(uuidString: beaconUUIDTextField.text!)!
        defaults.set(beaconUUID.uuidString, forKey: "beaconUUID")
        beaconUUIDTextField.text = beaconUUID.uuidString
        view.endEditing(true)
    }
    
    @IBAction func setMajorIDButton(_ sender: Any) {
        beaconMajor = Int(beaconMajorIDTextField.text!)!
        defaults.set(beaconMajor, forKey: "beaconMajor")
        beaconMajorIDTextField.text = String(beaconMajor)
        view.endEditing(true)
    }
    
    @IBAction func addMinorIDButton(_ sender: Any) {
        insertNewMinorID()
        addMinorIDTextField.text = ""
        view.endEditing(true)
    }
    
    func insertNewMinorID() {
        guard let val = Int(addMinorIDTextField.text!) else {
            return
        }
        beaconMinors.append(val)
        let indexPath = IndexPath(row: beaconMinors.count-1, section: 0)
        
        minorIDTable.beginUpdates()
        minorIDTable.insertRows(at: [indexPath], with: .automatic)
        minorIDTable.endUpdates()
        // now that updates are complete, update the user defaults
        beaconDict = makeBeaconDict(beacons: beaconMinors)
        defaults.set(beaconDict, forKey: "beaconDict")
        defaults.set(beaconMinors, forKey: "beaconMinors")
    }
    
    // make a dictionary from the minor IDs array
    func makeBeaconDict(beacons:Array<Int>) -> [String : Int] {
        /*
         Creates a dictionary which specifies, at which location in the measurements array the values obtained from a beacon are saved.
         */
        var beaconDict:[String:Int] = [:]
        var beaconIndex:Int = 0
        
        for beaconMinor in beacons.sorted() {  // sorted ensures, that beacons in both classes have the same order
            beaconDict[String(beaconMinor)] = beaconIndex
            beaconIndex += 1
        }
        return beaconDict
    }

}

extension ManageBeaconsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView {
        case minorIDTable:
            return beaconMinors.count
        default:
            // lets hope this never executes
            fatalError("Invalid Table!")
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch tableView {
        case minorIDTable:
            let minorID = beaconMinors[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "MinorIDCell") as! BeaconMinorTableViewCell
            cell.setLabel(minorID: minorID)
            return cell
        default:
            fatalError("Invalid Table!")
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch tableView {
        case minorIDTable:
            return true
        default:
            return true
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            switch tableView {
            case minorIDTable:
                beaconMinors.remove(at: indexPath.row)
                beaconDict = makeBeaconDict(beacons: beaconMinors)
                defaults.set(beaconDict, forKey: "beaconDict")
                defaults.set(beaconMinors, forKey: "beaconMinors")
            default:
                fatalError("Invalid Table!")
            }
            tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath], with: .automatic)
            tableView.endUpdates()
        }
    }
}
