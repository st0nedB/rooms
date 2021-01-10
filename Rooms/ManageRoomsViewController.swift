//
//  ManageBeaconMinorIDViewController.swift
//  Rooms
//
//  Created by Steffen Schieler on 09.05.20.
//  Copyright © 2020 Steffen Schieler. All rights reserved.
//

import UIKit

class ManageRoomsViewController: UIViewController {
    
    // user defaults
    let defaults = UserDefaults.standard
    
    var rooms: [String] = [ ]
    
    @IBOutlet weak var roomsTable: UITableView!
    @IBOutlet weak var addRoomTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Minor ID Table
        roomsTable.delegate = self
        roomsTable.dataSource = self
        roomsTable.tableFooterView = UIView(frame: CGRect.zero)
        
        // load user default rooms
        rooms = defaults.object(forKey: "rooms") as? [String] ?? [String()]
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        defaults.set(rooms, forKey: "rooms")
        print(defaults.object(forKey: "rooms") as! [String])
    }

    @IBAction func addNewRoomButton(_ sender: UIButton) {
        insertNewRoom()
        addRoomTextField.text = ""
        view.endEditing(true)
    }
    
    func insertNewRoom() {
        guard let val = addRoomTextField.text else {
            return
        }
        rooms.append(val)
        let indexPath = IndexPath(row: rooms.count-1, section: 0)
        
        defaults.set(rooms, forKey: "rooms")
        roomsTable.beginUpdates()
        roomsTable.insertRows(at: [indexPath], with: .automatic)
        roomsTable.endUpdates()
    }
}

extension ManageRoomsViewController: UITableViewDelegate, UITableViewDataSource {
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
            let cell = tableView.dequeueReusableCell(withIdentifier: "RoomCell") as! RoomTableViewCell
            cell.setLabel(room: room)
            return cell
        default:
            fatalError("Invalid Table!")
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch tableView {
        case roomsTable:
            return true
        default:
            return true
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            switch tableView {
            case roomsTable:
                rooms.remove(at: indexPath.row)
                defaults.set(rooms, forKey: "rooms")
            default:
                fatalError("Invalid Table!")
            }
            tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath], with: .automatic)
            tableView.endUpdates()
        }
    }
}

extension ManageRoomsViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        return true
    }
}
