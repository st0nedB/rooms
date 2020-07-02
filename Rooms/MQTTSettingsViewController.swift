//
//  MQTTSettingsViewController.swift
//  Rooms
//
//  Created by Steffen Schieler on 08.05.20.
//  Copyright © 2020 Steffen Schieler. All rights reserved.
//

import UIKit
import Moscapsule

class MQTTSettingsViewController: UIViewController, UITextFieldDelegate {
    
    // user defaults
    let defaults = UserDefaults.standard
    
    // IBOutlets and static variables
    @IBOutlet weak var mqttIPTextField: UITextField!
    @IBOutlet weak var mqttPortTextField: UITextField!
    @IBOutlet weak var mqttUsernameTextField: UITextField!
    @IBOutlet weak var mqttPasswordTextField: UITextField!
    @IBOutlet weak var mqttTopicTextField: UITextField!
    @IBOutlet weak var mqttTestImageView: UIImageView!
 
    var mqttIP:String = ""
    var mqttPort:UInt16 = 1883
    var mqttUser:String = ""
    var mqttPassword:String = ""
    var mqttTopic:String = ""
    var mqttStatus:Bool = false

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // read from user defaults
        mqttIP = defaults.string(forKey: "MQTTIP") as String? ?? "192.168.1.1"
        mqttPort = UInt16(defaults.integer(forKey: "MQTTPort") as Int? ?? 1883)
        mqttUser = defaults.string(forKey: "MQTTUsername") as String? ?? "admin"
        mqttPassword = defaults.string(forKey: "MQTTPassword") as String? ?? ""
        mqttTopic = defaults.string(forKey: "MQTTTopic") as String? ?? ""
        
        // set to the contents of the textfield
        mqttIPTextField.text = String(mqttIP)
        mqttPortTextField.text = String(mqttPort)
        mqttUsernameTextField.text = String(mqttUser)
        mqttPasswordTextField.text = String(mqttPassword)
        mqttTopicTextField.text = String(mqttTopic)
    }
    
    private func _validateIpAddress(ipToValidate: String) -> Bool {
        // thanks to Alin Golumbeanu @ stackoverflow
        //
        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()

        if ipToValidate.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
            // IPv6 peer.
            return true
        }
        else if ipToValidate.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1 {
            // IPv4 peer.
            return true
        }

        return false;
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

    @IBAction func setMQTTIP(_ sender: Any) {
        /*
        Input for MQTT IP
        */
        // split the input by the socket separator ":"
        let ip:String = String(mqttIPTextField.text ?? "192.168.1.1")
        
        // assign to variables
        if _validateIpAddress(ipToValidate: ip) {
            //MQTTSettingsViewController.mqttIP = ip
            defaults.set(ip, forKey: "MQTTIP")
        } else {
            _raiseAlert(alTitle: "Invalid Input!", alMessage: "Please enter a valid IP and Port, seperated by \":\"", logMessage: "Invalid Socket.")
        }
        
        view.endEditing(true)
    }
    
    @IBAction func setMQTTPort(_ sender: Any) {
        /*
        Input for MQTT Port
        */
        let port:String = String(mqttPortTextField.text ?? "1883")
        //MQTTSettingsViewController.mqttPort = UInt16(port) ?? 1883
        defaults.set(port, forKey: "MQTTPort")
        view.endEditing(true)
    }
    @IBAction func setMQTTUser(_ sender: Any) {
        /*
        Input for MQTT Username
        */
        //MQTTSettingsViewController.mqttUser = String(mqttUsernameTextField.text ?? "admin")
        let username = String(mqttUsernameTextField.text!)
        defaults.set(username, forKey: "MQTTUsername")
        mqttTestImageView.image = UIImage(named: "icons8-cancel") // to indicate that values have changed and config is untested
        view.endEditing(true)
    }
    
    @IBAction func setMQTTPassword(_ sender: Any) {
        /*
        Input for MQTT Password
        */
        //MQTTSettingsViewController.mqttPassword = String(mqttPasswordTextField.text!)
        let password = String(mqttPasswordTextField.text!)
        defaults.set(password, forKey: "MQTTPassword")
        mqttTestImageView.image = UIImage(named: "icons8-cancel")  // to indicate that values have changed and config is untested
        view.endEditing(true)
    }
    
    @IBAction func setMQTTTopic(_ sender: Any) {
        /*
        Input for MQTT Topic
        */
        //MQTTSettingsViewController.mqttTopic = String(mqttTopicTextField.text!)
        let topic = String(mqttTopicTextField.text!)
        defaults.set(topic, forKey: "MQTTTopic")
        mqttTestImageView.image = UIImage(named: "icons8-cancel")  // to indicate that values have changed and config is untested
        view.endEditing(true)
    }
    
    @IBAction func testMQTTconnection(_ sender: Any) {
        // stop activity and hide
        mqttTestImageView.isHidden = true
        
        
        // publish success
        var mqttPublished:Bool = false
        
        // setup the MQTT connection
        let mqttConfig = MQTTConfig(
            clientId: mqttUser ,
            host: mqttIP,
            port: Int32(mqttPort),
            keepAlive: 5
        )
        
        mqttConfig.mqttAuthOpts = MQTTAuthOpts(
            username: mqttUser,
            password: mqttPassword
        )
        
        mqttConfig.onConnectCallback = { returnCode in
            print("Return Code is \(returnCode.description)")
        }
        mqttConfig.onPublishCallback = { messageId in
            // successful publish
            mqttPublished = true
        }
        
        // create new MQTT Connection
        let mqttClient = MQTT.newConnection(mqttConfig, connectImmediately: true)
        mqttClient.publish(
            string: "MQTT-Testmessage from Rooms. Congraz, it works :)",
            topic: mqttTopic,
            qos: 0,
            retain: true
        )
        // for some reason, qos = 2 does not work. maybe its a server error?

        // disconnect
        mqttClient.disconnect()
        
        sleep(1) // un-elegant solution to wait for the callback thread to finish before the if-statement below is executed
        if mqttPublished {
            // if the conenction works
            mqttTestImageView.image = UIImage(named: "icons8-ok")
        } else {
            // if the conenction doesnt work
            mqttTestImageView.image = UIImage(named: "icons8-cancel")
        }
        
        // stop activity and hide
        mqttTestImageView.isHidden = false
    }
    
}
