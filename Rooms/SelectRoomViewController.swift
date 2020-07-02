//
//  ManageBeaconMinorIDViewController.swift
//  Rooms
//
//  Created by Steffen Schieler on 09.05.20.
//  Copyright © 2020 Steffen Schieler. All rights reserved.
//

import UIKit

class SelectRoomsViewController: UIViewController, UITextFieldDelegate {
    
    // load user defaults
    let defaults = UserDefaults.standard
    
    // to load the rooms from the user defaults
    var rooms:[String] = [String()]
    
    // For the delegate connection
    var RoomDelegate: SelectRoomDelegate? = nil
    
    // IBOutlets
    @IBOutlet weak var roomsTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // load the user defaults for the rooms
        rooms = defaults.object(forKey: "rooms") as? [String] ?? [String()]
        
        // Minor ID Table
        roomsTable.delegate = self
        roomsTable.dataSource = self
        roomsTable.tableFooterView = UIView(frame: CGRect.zero)
    }
    
    func readFiles(room: String) -> (numMeasurements: Int, numBeacons: Int) {
        /*
         Read a room file and return the # Measurements and # Beacons
         */
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            // process files
            let file = fileURLs.filter{ $0.lastPathComponent == (room + ".json") }
            if !file.isEmpty {
                let data = try Data(contentsOf: file[0], options: .mappedIfSafe)
                let json = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
                let measurements = json as? Array<Array<Array<Double>>> // TODO: caution, this likely need change
                // now parse the dimensions of the array
                let numBeacons = measurements![0].count
                let numMeasurements = measurements!.count
                //
                return (numMeasurements, numBeacons)
            } else {
                let numBeacons:Int = 0
                let numMeasurements:Int = 0
                return (numMeasurements, numBeacons)
            }
        } catch {
            fatalError("Error while checking and reading of measurement file.")
        }
    }
    
}

extension SelectRoomsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView {
        case roomsTable:
            return rooms.count
        default:
            // lets hope this never executes
            fatalError("Invalid Table!")
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch tableView {
        case roomsTable:
            let room = rooms[indexPath.row]
            let roominfo = readFiles(room: room)
            let cell = tableView.dequeueReusableCell(withIdentifier: "SelectRoomCell") as! RoomSelectTableViewCell
            cell.setLabels(room: room, numMeasurements: roominfo.numMeasurements, numBeacons: roominfo.numBeacons )
            return cell
        default:
            fatalError("Invalid Table!")
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedRoom = rooms[indexPath.row]
        if self.RoomDelegate != nil {
            self.RoomDelegate?.UpdateSelectedRoom(selectedRoom: selectedRoom)
        }
        dismiss(animated: true, completion: nil)
    }
    
}

protocol SelectRoomDelegate: class {
    func UpdateSelectedRoom(selectedRoom: String)
}
