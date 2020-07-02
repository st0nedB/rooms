//
//  SettingsViewController.swift
//  Rooms
//
//  Created by Steffen Schieler on 08.05.20.
//  Copyright © 2020 Steffen Schieler. All rights reserved.
//

import UIKit
import CoreLocation

class SettingsViewController: UIViewController, UITextFieldDelegate {
    
    // user defaults
    let defaults = UserDefaults.standard
    
    @IBOutlet weak var locatizationAuthorizationImage: UIImageView!
    @IBOutlet weak var localizationAuthorizationTextView: UITextView!
    // Sampling Settings
    @IBOutlet weak var numSamplesTextField: UITextField!
    var numCollectSamples:Int = 120
    
    override func viewDidLoad() {
        super.viewDidLoad()
        numCollectSamples = defaults.integer(forKey: "numCollectSamples") as Int? ?? 120
        numSamplesTextField.text = String(numCollectSamples)
        
        // inform the user about the always-authorization for the location
        var authStatusString:String = ""
        if CLLocationManager.authorizationStatus() != .authorizedAlways {
            authStatusString = """
                To track your rooms in the background, authorize the app to always use your location.
                Rooms will never use your GNSS location. It will only perform Bluetooth Beacon ranging in your homezone.
            """
            locatizationAuthorizationImage.image = UIImage(named: "icons8-brake-warning-100")
        } else {
            authStatusString = """
            Rooms is authorized to use your location in the background. Prediction will continue if the app is minimized.
            Rooms will never use your GNSS location. It will only perform Bluetooth Beacon ranging in your homezone.
            """
            locatizationAuthorizationImage.image = UIImage(named: "icons8-ok")
        }
        let authStatus = NSMutableAttributedString(string: authStatusString)
        localizationAuthorizationTextView.attributedText = authStatus
    }

    private func _validateConfig() {

    }
    
    private func _raiseAlert(alTitle: String, alMessage: String, logMessage: String) {
        let alert = UIAlertController(title: alTitle, message: alMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
        NSLog(logMessage)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    /*
    ---------------------------------
    IBOutlets from the ViewController
    ---------------------------------
    */
    
    @IBAction func setNumSamples(_ sender: Any) {
        let numSamples = Int(numSamplesTextField.text!)
        defaults.set(numSamples, forKey: "numCollectSamples")
        view.endEditing(true)
    }
    
}
