//
//  ModelSettingsViewController.swift
//  Rooms
//
//  Created by Steffen Schieler on 08.05.20.
//  Copyright © 2020 Steffen Schieler. All rights reserved.
//

import UIKit
import CoreML

class ModelSettingsViewController: UIViewController, UITextFieldDelegate {
    
    let defaults = UserDefaults.standard

    var dataFiles = trainingDataFiles()
    var modelURL:String = ""
    var model = MLModel()
    var downloadSuccess = false
    static let modelName:String = "prediction.mlmodel"  // the downloaded file will be renamed to this filename
    
    @IBOutlet weak var modelURLTextfield: UITextField!
    @IBOutlet weak var downloadImageView: UIImageView!
    @IBOutlet weak var compileImageView: UIImageView!
    @IBOutlet weak var downloadProgressLabel: UILabel!
    @IBOutlet weak var compileProgressLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        modelURLTextfield.text = defaults.string(forKey: "modelURL") ?? "URL to *.mlmodel file"
    }
    
    func _downloadModel(url: String) -> (Bool) {
            
        if let imageURL = getURLFromString(url) {
            download(from: imageURL)
        }

        let downloadStart = Date()
        // wait for download to finish or a five minute timer to run out
        while !downloadSuccess || (downloadStart + 10) < Date() {
            sleep(1)
        }
        
        return true
    }
    
    func testCompileModel() -> (Bool){
        // get the model file
        let fileManager = FileManager.default
        let documentsURL = try! fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let modelURL = documentsURL.appendingPathComponent(ModelSettingsViewController.modelName)

        if !fileManager.fileExists(atPath: modelURL.path) {
            return false
        }
        compileProgressLabel.text = "33 %"
        
        // check if we can compile the model -> Error Code 1
        guard let compiledModelURL = try? MLModel.compileModel(at: modelURL) else {
            return false
        }
        compileProgressLabel.text = "66 %"
        
        // check if the model can be used as MLModel -> Error Code 2
        do {
            model = try MLModel(contentsOf: compiledModelURL)
        } catch {
            return false
        }
        compileProgressLabel.text = "100 %"
        
        return true
    }
    
    func verifyURL(urlString: String?) -> Bool {
        /*
         Verifies a URL
         Credit to:
         https://stackoverflow.com/questions/28079123/how-to-check-validity-of-url-in-swift
        */
        if let urlString = urlString {
            if let url = NSURL(string: urlString) {
                return UIApplication.shared.canOpenURL(url as URL)
            }
        }
        return false
        }
    
    @IBAction func setURL(_ sender: Any) {
        /*
        Uploades the files to the server to generate the model and return it back to the device.
         A warning information about the upload is printed.
         No metadata used.
        */
        /*guard let url = URL(string: "http://10.0.0.254:9002/rooms_model.mlmodel") else { return }
        */
        
        if verifyURL(urlString: modelURLTextfield.text) {
            modelURL = modelURLTextfield.text ?? ""
        }
        
        defaults.set(modelURL, forKey: "modelURL")
        view.endEditing(true)
    }
    
    @IBAction func importModelButton(_ sender: Any) {
        // download the model
        
        if !_downloadModel(url: modelURL) {
            // download failed
            downloadImageView.image = UIImage(named: "icons8-cancel")
            return
        } else {
            downloadImageView.image = UIImage(named: "icons8-ok")
        }

        if !testCompileModel() {
            // compilation failed
            compileImageView.image = UIImage(named: "icons8-cancel")
        } else {
            // compilation succesful
            compileImageView.image = UIImage(named: "icons8-ok")
        }
    }

}

extension ModelSettingsViewController: URLSessionDownloadDelegate {
    // For further details of the implementation refer to:
    // https://medium.com/swlh/tracking-download-progress-with-urlsessiondownloaddelegate-5174147009f (Shawon Ashraf)
    
    // MARK: prepare url from string
    func getURLFromString(_ str: String) -> URL? {
        return URL(string: str)
    }
    
    // MARK: fetch image from url
    func download(from url: URL) {
        let configuration = URLSessionConfiguration.default
        let operationQueue = OperationQueue()
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: operationQueue)
            
        let downloadTask = session.downloadTask(with: url)
        downloadTask.resume()
    }
    
    // MARK: protocol stub for tracking download progress
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            
        let percentDownloaded = totalBytesWritten / totalBytesExpectedToWrite
        // update the percentage label
        DispatchQueue.main.async {
            self.downloadProgressLabel.text = "\(percentDownloaded * 100) %"
        }
    }
    
    // MARK: protocol stub for download completion tracking
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        //
        let documentsURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let savedURL = documentsURL.appendingPathComponent(ModelSettingsViewController.modelName)
        try? FileManager.default.removeItem(at: savedURL)
        do {
            try FileManager.default.moveItem(at: location, to: savedURL)
        } catch {
            print("Could not move file to desired location!")
        }
        downloadSuccess = true
    }
    
}
