//
//  ImageAudioViewController.swift
//  ExperiencesSprint
//
//  Created by Jorge Alvarez on 3/13/20.
//  Copyright © 2020 Jorge Alvarez. All rights reserved.
//

import UIKit
import CoreImage
import Photos
import CoreImage.CIFilterBuiltins // iOS 13 *
import AVFoundation

class ImageAudioViewController: UIViewController {
    
    // MARK: - Properties

    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var recordAudioButton: UIButton!
    @IBOutlet weak var addImageButton: UIButton!
    
    private var originalImage: UIImage? {
        didSet {
            guard let originalImage = originalImage else {return}
            var scaledSize = imageView.bounds.size
            let scale = UIScreen.main.scale // 1x 2x or 3x or more
            scaledSize = CGSize(width: scaledSize.width * scale, height: scaledSize.height * scale)
            scaledImage = originalImage.imageByScaling(toSize: scaledSize)
        }
    }
    
    private var scaledImage: UIImage? {
        didSet {
            updateImage()
        }
    }
    
    /// Allows us to render the image (like an oven for baking bread)
    private let context = CIContext(options: nil)
    
    let experienceController = ExperienceController()
    
    var audioRecorder: AVAudioRecorder?
    var recordingURL: URL?
    
    var isRecording: Bool {
        return audioRecorder?.isRecording ?? false
    }
    
    // MARK: - Actions
    
    /// This doesn't get called for some reason, have to do this logic in "prepare for segue"
    @IBAction func nextTapped(_ sender: UIBarButtonItem) {
        print("nextTapped")
        guard let comment = titleTextField.text, !comment.isEmpty else { return }
        
        masterExperienceController.comment = comment
        masterExperienceController.image = filterImage(scaledImage ?? UIImage(named: "tom")!)
        masterExperienceController.audioURL = recordingURL
        
        performSegue(withIdentifier: "AddVideoSegue", sender: self)
    }
    
    @IBAction func addImageTapped(_ sender: UIButton) {
        print("addImageTapped")
        presentImagePickerController()
    }
    
    @IBAction func recordAudioTapped(_ sender: UIButton) {
        print("recordAudioTapped")
        if isRecording {
            stopRecording()
        } else {
            requestPermissionOrStartRecording()
        }
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleTextField.delegate = self
        try? prepareAudioSession()
    }
    
    // MARK: - Image
    
    func filterImage(_ image: UIImage) -> UIImage? {
        // UIImage -> CGImage -> CIImage
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        
        /// Should these be properties???
        let filter = CIFilter.colorControls()
        
        /// Input
        filter.inputImage = ciImage
        filter.saturation = 0 // black and white
        
        /// Output
        guard let outputCIImage = filter.outputImage else { return nil }
        
        // CIImage -> CGImage -> UIImage
        // Render the image (apply the filter to the image). Baking the cookies in the oven
        guard let outputCGImage = context.createCGImage(outputCIImage, from: CGRect(origin: .zero, size: image.size)) else { return nil }
        return UIImage(cgImage: outputCGImage)
    }
    
    private func updateImage() {
        if let scaledImage = scaledImage {
            imageView.image = filterImage(scaledImage)
        } else {
            imageView.image = nil // allows us to clear out the image
        }
    }
    
    private func presentImagePickerController() {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
            print("Error: the photo library is unavailable")
            return
        }
        
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        present(imagePicker, animated: true)
    }
    
    // MARK: - Audio
    
    // If you don't set active, on a device record won't work the first time (or other strange behavior)
    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try session.setActive(true, options: []) // can fail if on a phone call, for instance
    }
    
    func updateViews() {
        recordAudioButton.isSelected = isRecording
    }
    
    func createNewRecordingURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let name = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: .withInternetDateTime)
        let file = documents.appendingPathComponent(name, isDirectory: false).appendingPathExtension("caf")
        
        print("recording URL: \(file)")
        
        return file
    }
    
    func requestPermissionOrStartRecording() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                guard granted == true else {
                    print("We need microphone access") // Privacy for microphone denied
                    return
                }
                
                print("Recording permission has been granted!")
                // NOTE: Invite the user to tap record again, since we just interrupted them, and they may not have been ready to record
            }
        case .denied:
            print("Microphone access has been blocked.")
            
            let alertController = UIAlertController(title: "Microphone Access Denied", message: "Please allow this app to access your Microphone.", preferredStyle: .alert)
            
            alertController.addAction(UIAlertAction(title: "Open Settings", style: .default) { (_) in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            })
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
            
            present(alertController, animated: true, completion: nil)
        case .granted:
            startRecording()
        @unknown default:
            break
        }
    }
    
    func startRecording() {
        // 44.1 kHz
        print("Start Recording")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let recordingURL = createNewRecordingURL()
        audioRecorder = try? AVAudioRecorder(url: recordingURL, format: format)
        audioRecorder?.record()
        audioRecorder?.delegate = self
        //audioRecorder?.isMeteringEnabled = true
        self.recordingURL = recordingURL
        updateViews()
    }
    
    func stopRecording() {
        print("Stop Recording")
        audioRecorder?.stop()
        updateViews()
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "AddVideoSegue" {
            print("AddVideoSegue")
            if let vidVC = segue.destination as? VideoViewController {
                guard let comment = titleTextField.text, !comment.isEmpty else { return }
                
                masterExperienceController.comment = comment
                masterExperienceController.image = filterImage(scaledImage ?? UIImage(named: "tom")!)
                masterExperienceController.audioURL = recordingURL
                print(vidVC)
            }
        }
    }
}

// MARK: - Extensions

/// For accessing the photo library
extension ImageAudioViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        print("Picked Image")
        
        if let image = info[.originalImage] as? UIImage {
            originalImage = image
        }
        picker.dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        print("Cancel")
        picker.dismiss(animated: true, completion: nil)
    }
    
}

/// So images don't flip
extension UIImage {
    
    /// Resize the image to a max dimension from size parameter
    func imageByScaling(toSize size: CGSize) -> UIImage? {
        guard size.width > 0 && size.height > 0 else { return nil }
        
        let originalAspectRatio = self.size.width/self.size.height
        var correctedSize = size
        
        if correctedSize.width > correctedSize.width*originalAspectRatio {
            correctedSize.width = correctedSize.width*originalAspectRatio
        } else {
            correctedSize.height = correctedSize.height/originalAspectRatio
        }
        
        return UIGraphicsImageRenderer(size: correctedSize, format: imageRendererFormat).image { context in
            draw(in: CGRect(origin: .zero, size: correctedSize))
        }
    }
    
    /// Renders the image if the pixel data was rotated due to orientation of camera
    var flattened: UIImage {
        if imageOrientation == .up { return self }
        return UIGraphicsImageRenderer(size: size, format: imageRendererFormat).image { context in
            draw(at: .zero)
        }
    }
}

extension ImageAudioViewController: AVAudioRecorderDelegate {
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Error recording: \(error)")
        }
    }
}

extension ImageAudioViewController: UITextFieldDelegate {
    // Thanks, Paul's Youtube video
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        titleTextField.resignFirstResponder()
        return true
    }
}
