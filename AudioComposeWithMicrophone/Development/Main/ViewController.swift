//
//  ViewController.swift
//  AudioComposeWithMicrophone
//
//  Created by Sahan Ravindu on 2022-04-04.
//

import UIKit
import AVFoundation
import CoreData

class ViewController: UIViewController, AVAudioRecorderDelegate, AVAudioPlayerDelegate, UITextFieldDelegate {
    
    @IBOutlet weak var saveButtonOutlet: UIBarButtonItem!
    
    @IBOutlet weak var soundNoteTitleLable: UILabel!
    @IBOutlet weak var soundSaveConfirmationLabel: UILabel!
    @IBOutlet weak var soundsRecordPlayStatusLabel: UILabel!
    
    @IBOutlet weak var soundTitleTextField: UITextField!
    
    @IBOutlet weak var recordButtonOutlet: UIButton!
    @IBOutlet weak var stopButtonOutlet: UIButton!
    @IBOutlet weak var playButtonOutlet: UIButton!
    
    var soundsNoteID: String!        // populated from incoming seque
    var soundsNoteTitle: String!     // populated from incoming seque
    var soundURL: String!            // store in CoreData
    var audioRecorder:AVAudioRecorder?
    var audioPlayer:AVAudioPlayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        // Microphone Authorization/Permission
        checkMicrophoneAccess()
        
        // saveButtonOutlet.isEnabled = false
        self.navigationController?.navigationBar.tintColor = .white
        soundTitleTextField.delegate = self
        soundNoteTitleLable.text = soundsNoteTitle
        soundSaveConfirmationLabel.alpha = 0
        
        // Disable Stop/Play button when application launches
        stopButtonOutlet.isEnabled = false
        playButtonOutlet.isEnabled = false
        
        // Set the audio file
        let directoryURL = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in:
                                                        FileManager.SearchPathDomainMask.userDomainMask).first
        
        let audioFileName = UUID().uuidString + ".m4a"
        let audioFileURL = directoryURL!.appendingPathComponent(audioFileName)
        soundURL = audioFileName       // Sound URL to be stored in CoreData
        
        // Setup audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playAndRecord)), mode: .default)
        } catch _ {
        }
        
        // Define the recorder setting
        let recorderSetting = [AVFormatIDKey: NSNumber(value: kAudioFormatMPEG4AAC as UInt32),
                             AVSampleRateKey: 44100.0,
                       AVNumberOfChannelsKey: 2 ]
        
        audioRecorder = try? AVAudioRecorder(url: audioFileURL, settings: recorderSetting)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
        
        soundsRecordPlayStatusLabel.text = "Ready to Record"
        // Hides Navigation Controller Thin Line Shadow Bar
        self.navigationController?.navigationBar.setValue(true, forKey: "hidesShadow")
        
        
    }
    
    @IBAction func didClickRecord(_ sender: Any) {
        soundSaveConfirmationLabel.text = ""
        
        // Stop the audio player before recording
        if let player = audioPlayer {
            if player.isPlaying {
                player.stop()
                playButtonOutlet.setImage(UIImage(named: "Play-Jolly"), for: UIControl.State())
                playButtonOutlet.isSelected = false
            }
        }
        
        if let recorder = audioRecorder {
            if !recorder.isRecording {
                let audioSession = AVAudioSession.sharedInstance()
                try? audioSession.setCategory(.playAndRecord, mode: .default, policy: .default, options: .defaultToSpeaker)
                do {
                    try audioSession.setActive(true)
                } catch _ {
                }
                
                // Start recording
                recorder.record()
                
                soundsRecordPlayStatusLabel.text = "Recording .."
                
                recordButtonOutlet.setImage(UIImage(named: "Microphone-Jolly"), for: UIControl.State.selected)
                stopButtonOutlet.setImage(UIImage(named: "Stop-Jolly"), for: UIControl.State())
                playButtonOutlet.setImage(UIImage(named: "Play-Outlined"), for: UIControl.State())
                
                recordButtonOutlet.isSelected = true
                
                stopButtonOutlet.isEnabled = true
                playButtonOutlet.isEnabled = false
                
            } else {
                // Pause recording
                
                recorder.pause()
                
                soundsRecordPlayStatusLabel.text = "Paused!"
                
                recordButtonOutlet.setImage(UIImage(named: "Microphone-Pause"), for: UIControl.State())
                playButtonOutlet.setImage(UIImage(named: "Play-Outlined"), for: UIControl.State.selected)
                stopButtonOutlet.setImage(UIImage(named: "Stop-Outlined"), for: UIControl.State())
                
                stopButtonOutlet.isEnabled = false
                playButtonOutlet.isEnabled = false
                recordButtonOutlet.isSelected = false
                
            }
        }
    }
    
    @IBAction func didClickStop(_ sender: Any) {
        
        soundsRecordPlayStatusLabel.text = "Stopped!"
        
        recordButtonOutlet.setImage(UIImage(named: "Microphone-Jolly"), for: UIControl.State())
        playButtonOutlet.setImage(UIImage(named: "Play-Jolly"), for: UIControl.State())
        stopButtonOutlet.setImage(UIImage(named: "Stop-Outlined"), for: UIControl.State())
        
        recordButtonOutlet.isSelected = false
        playButtonOutlet.isSelected = false
        
        stopButtonOutlet.isEnabled = false
        playButtonOutlet.isEnabled = true
        recordButtonOutlet.isEnabled = true
        
        if let recorder = audioRecorder {
            if recorder.isRecording {
                audioRecorder?.stop()
                let audioSession = AVAudioSession.sharedInstance()
                do {
                    try audioSession.setActive(false)
                } catch _ {
                }
            }
        }
        
        // Stop the audio player if playing
        if let player = audioPlayer {
            if player.isPlaying {
                player.stop()
            }
        }
        // If user recorded then stopped then allow SAVE now (even without a title)
        saveButtonOutlet.isEnabled = true
    }
    
    @IBAction func didClickPlay(_ sender: Any) {
        if let recorder = audioRecorder {
            if !recorder.isRecording {
                audioPlayer = try? AVAudioPlayer(contentsOf: recorder.url)
                audioPlayer?.delegate = self
                audioPlayer?.play()
                audioPlayer?.volume = 1.0
                playButtonOutlet.setImage(UIImage(named: "Play-Outlined"), for: UIControl.State.selected)
                playButtonOutlet.isSelected = true
                stopButtonOutlet.isEnabled = true
                
                soundsRecordPlayStatusLabel.text = "Playing .."
                
                stopButtonOutlet.setImage(UIImage(named: "Stop-Jolly"), for: UIControl.State())
                recordButtonOutlet.setImage(UIImage(named: "Microphone-Outlined"), for: UIControl.State())
                recordButtonOutlet.isEnabled = false
                
            }
        }
        
    }
    
    // Save when recording is completed
    @IBAction func soundSaveButtonAction(_ sender: AnyObject) {
        
//        let soundsContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
//
//        let sound = NSEntityDescription.insertNewObject(forEntityName: "Sounds", into: soundsContext) as! Sounds
//
//        sound.noteID = soundsNoteID         // V2.0
//        sound.noteTitle = soundsNoteTitle
//        sound.noteSoundURL = soundURL
//
//        var noteSoundTitle:String = "Sound " + Common().stringCurrentDate()
//
//        if (soundTitleTextField.text?.isEmpty)! {
//            noteSoundTitle = "Sound " + Common().stringCurrentDate()
//            soundTitleTextField.text = noteSoundTitle
//        } else {
//            noteSoundTitle =  soundTitleTextField.text!
//        }
//
//        sound.noteSoundTitle =  noteSoundTitle
//        do {
//            try soundsContext.save()
//        } catch _ {
//        }
//        soundSaveConfirmationLabel.alpha = 1
//        soundSaveConfirmationLabel.text = "Saved " + noteSoundTitle
//        soundSaveConfirmationLabel.adjustsFontSizeToFitWidth = true
//        soundTitleTextField.text = ""
//
//        // Set the audio recorder ready to record the next audio with a unique audioFileName
//        let directoryURL = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in:
//                                                        FileManager.SearchPathDomainMask.userDomainMask).first // as! NSURL
//
//        let audioFileName = UUID().uuidString + ".m4a"
//        let audioFileURL = directoryURL!.appendingPathComponent(audioFileName)
//        soundURL = audioFileName       // Sound URL to be stored in CoreData
//
//        // Setup audio session
//        let audioSession = AVAudioSession.sharedInstance()
//        do {
//            try audioSession.setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playAndRecord)), mode: .default)
//        } catch _ {
//        }
//
//        // Define the recorder setting
//        let recorderSetting = [AVFormatIDKey: NSNumber(value: kAudioFormatMPEG4AAC as UInt32),
//                             AVSampleRateKey: 44100.0,
//                       AVNumberOfChannelsKey: 2 ]
//
//        audioRecorder = try? AVAudioRecorder(url: audioFileURL, settings: recorderSetting)
//        audioRecorder?.delegate = self
//        audioRecorder?.isMeteringEnabled = true
//        audioRecorder?.prepareToRecord()
//
//        soundsRecordPlayStatusLabel.text = "Ready to Record"
//
//        playButtonOutlet.isEnabled = false
//        stopButtonOutlet.isEnabled = false
//        saveButtonOutlet.isEnabled = false
//        playButtonOutlet.setImage(UIImage(named: "Play-Outlined"), for: UIControl.State())
        
    }
    
    // Show Save Only if a Title is Entered (otherwise a blank title record is saved!)a
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let oldText = textField.text! as NSString
        let newText = oldText.replacingCharacters(in: range, with: string) as NSString
        saveButtonOutlet.isEnabled = (newText.length > 0)  // implied if; as isEnabled is a Bool true/false
        return true
    } // end func textField
    
}

extension ViewController {
    // SoundsViewController.swift
    // completion of recording
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            
            soundsRecordPlayStatusLabel.text = "Recording Completed"
            
            recordButtonOutlet.setImage(UIImage(named: "Microphone-Jolly"), for: UIControl.State())
            playButtonOutlet.setImage(UIImage(named: "Play-Jolly"), for: UIControl.State())
            stopButtonOutlet.setImage(UIImage(named: "Stop-Outlined"), for: UIControl.State())
            
            recordButtonOutlet.isEnabled = true
            playButtonOutlet.isEnabled = true
            stopButtonOutlet.isEnabled = false
            
        }
    }
    
    // Completion of playing
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        
        soundsRecordPlayStatusLabel.text = "Playing Completed"
        
        recordButtonOutlet.setImage(UIImage(named: "Microphone-Jolly"), for: UIControl.State())
        playButtonOutlet.setImage(UIImage(named: "Play-Jolly"), for: UIControl.State())
        stopButtonOutlet.setImage(UIImage(named: "Stop-Outlined"), for: UIControl.State())
        
        playButtonOutlet.isSelected = false
        stopButtonOutlet.isEnabled = false
        recordButtonOutlet.isEnabled = true
        
    }
}

extension ViewController {
    // Keboard Control Functions: Return
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        soundTitleTextField.resignFirstResponder()   // When the Enter key is pressed on the keyboard the keyboard will be dismissed.
        return false
    }
    
    // Keyboard Control
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true);
    }
}

extension ViewController {
    // Microphone Access
    func checkMicrophoneAccess() {
        // Check Microphone Authorization
        switch AVAudioSession.sharedInstance().recordPermission {
            
        case AVAudioSession.RecordPermission.granted:
            print(#function, " Microphone Permission Granted")
            break
            
        case AVAudioSession.RecordPermission.denied:
            // Dismiss Keyboard (on UIView level, without reference to a specific text field)
            UIApplication.shared.sendAction(#selector(UIView.endEditing(_:)), to:nil, from:nil, for:nil)
            
            AlertProvider(vc: self).showAlertWithActions(title: "Microphone Error!", message: "8Code is Not Authorized to Access the Microphone!", actions: [AlertAction(title: "Settings"), AlertAction(title: "Cancel", style: .cancel)]) { action in
                if action.title == "Settings" {
                    DispatchQueue.main.async {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
                        }
                    } // end dispatchQueue
                }
            }
            
            return
            
        case AVAudioSession.RecordPermission.undetermined:
            print("Request permission here")
            // Dismiss Keyboard (on UIView level, without reference to a specific text field)
            UIApplication.shared.sendAction(#selector(UIView.endEditing(_:)), to:nil, from:nil, for:nil)
            
            AVAudioSession.sharedInstance().requestRecordPermission({ (granted) in
                // Handle granted
                if granted {
                    print(#function, " Now Granted")
                } else {
                    print("Pemission Not Granted")
                    
                } // end else
            })
        @unknown default:
            print("ERROR! Unknown Default. Check!")
        } // end switch
        
    } // end func checkMicrophoneAccess
}

// Helper function inserted by Swift migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
    return input.rawValue
}

// Helper function inserted by Swift migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
