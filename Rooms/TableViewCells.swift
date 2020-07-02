//
//  RoomTableViewCell.swift
//  Rooms
//
//  Created by Steffen Schieler on 08.05.20.
//  Copyright © 2020 Steffen Schieler. All rights reserved.
//

import UIKit

class RoomTableViewCell: UITableViewCell {
    
    @IBOutlet weak var labelRoom: UILabel!
    
    func setLabel(room: String) {
        labelRoom.text = room
    }
}

class BeaconMinorTableViewCell: UITableViewCell {
    @IBOutlet weak var labelMinorID: UILabel!
    
    func setLabel(minorID: Int) {
        labelMinorID.text = String(minorID)
    }
    
}

class RoomSelectTableViewCell: UITableViewCell {
    
    @IBOutlet weak var labelRoom: UILabel!
    @IBOutlet weak var labelDetail: UILabel!
    
    func setLabels(room: String, numMeasurements: Int, numBeacons: Int) {
        labelRoom.text = room
        labelDetail.text = String(format: "%d measurements, %d beacons", arguments: [numMeasurements, numBeacons])
    }
}
