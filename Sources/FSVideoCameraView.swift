//
//  FSVideoCameraView.swift
//  Fusuma
//
//  Created by Brendan Kirchner on 3/18/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import AVFoundation

@objc protocol FSVideoCameraViewDelegate: class {
    func videoFinished(withFileURL fileURL: URL)
}

final class FSVideoCameraView: UIView {

    @IBOutlet weak var previewViewContainer: UIView!
    @IBOutlet weak var shotButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var flipButton: UIButton!
    @IBOutlet weak var videoProgressView: UIProgressView?
    
    weak var delegate: FSVideoCameraViewDelegate? = nil
    
    var session: AVCaptureSession?
    var device: AVCaptureDevice?
    var videoInput: AVCaptureDeviceInput?
    var videoOutput: AVCaptureMovieFileOutput?
    var focusView: UIView?
    
    var flashOffImage: UIImage?
    var flashOnImage: UIImage?
    var videoStartImage: UIImage?
    var videoStopImage: UIImage?

    var shouldRotate = false
    //ProgressView
    var audioTimeCounter =  0.0
    var audioLimitTime = 30.0
    var timer = Timer()
    var timerIsOn = false
    
    fileprivate var isRecording = false
    
    static func instance() -> FSVideoCameraView {
        return UINib(nibName: "FSVideoCameraView", bundle: Bundle(for: self.classForCoder())).instantiate(withOwner: self, options: nil)[0] as! FSVideoCameraView
    }
    
    func initialize() {
        
        if session != nil { return }
        
        self.backgroundColor = fusumaBackgroundColor
        
        self.isHidden = false
        
        // AVCapture
        session = AVCaptureSession()
        session?.sessionPreset = AVCaptureSessionPresetMedium
        guard let session = session else { return }
        
        for device in AVCaptureDevice.devices() {
            if let device = device as? AVCaptureDevice, device.position == AVCaptureDevicePosition.back {
                self.device = device
            }
        }
        
        do {
            
            videoInput = try AVCaptureDeviceInput(device: device)
            
            session.addInput(videoInput)
            
            videoOutput = AVCaptureMovieFileOutput()
            let totalSeconds = 31.0 //Total Seconds of capture time
            let timeScale: Int32 = 30 //FPS
            
            let maxDuration = CMTimeMakeWithSeconds(totalSeconds, timeScale)
            
            videoOutput?.maxRecordedDuration = maxDuration
            videoOutput?.minFreeDiskSpaceLimit = 1024 * 1024 //SET MIN FREE SPACE IN BYTES FOR RECORDING TO CONTINUE ON A VOLUME
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
            
            let videoLayer = AVCaptureVideoPreviewLayer(session: session)
            videoLayer?.frame = self.previewViewContainer.bounds
            videoLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
            
            self.previewViewContainer.layer.addSublayer(videoLayer!)
            
            session.startRunning()
            
            // Focus View
            self.focusView         = UIView(frame: CGRect(x: 0, y: 0, width: 90, height: 90))
            let tapRecognizer      = UITapGestureRecognizer(target: self, action: #selector(FSVideoCameraView.focus(_:)))
            self.previewViewContainer.addGestureRecognizer(tapRecognizer)
            
        } catch { }
        
        let bundle = Bundle(for: self.classForCoder)
        
        flashOnImage = fusumaFlashOnImage != nil ? fusumaFlashOnImage : UIImage(named: "ic_flash_on", in: bundle, compatibleWith: nil)
        flashOffImage = fusumaFlashOffImage != nil ? fusumaFlashOffImage : UIImage(named: "ic_flash_off", in: bundle, compatibleWith: nil)
        let flipImage = fusumaFlipImage != nil ? fusumaFlipImage : UIImage(named: "ic_loop", in: bundle, compatibleWith: nil)
        videoStartImage = fusumaVideoStartImage != nil ? fusumaVideoStartImage : UIImage(named: "video_button", in: bundle, compatibleWith: nil)
        videoStopImage = fusumaVideoStopImage != nil ? fusumaVideoStopImage : UIImage(named: "video_button_rec", in: bundle, compatibleWith: nil)
        
        if fusumaTintIcons {
            flashButton.tintColor = fusumaBaseTintColor
            flipButton.tintColor  = fusumaBaseTintColor
            flashButton.setImage(flashOffImage?.withRenderingMode(.alwaysTemplate), for: UIControlState())
            flipButton.setImage(flipImage?.withRenderingMode(.alwaysTemplate), for: UIControlState())
        } else {
            flashButton.setImage(flashOffImage, for: UIControlState())
            flipButton.setImage(flipImage, for: UIControlState())
        }
        
        flashConfiguration()
        
        self.startCamera()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func startCamera() {
        let status = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        if status == AVAuthorizationStatus.authorized {
            session?.startRunning()
        } else if status == AVAuthorizationStatus.denied || status == AVAuthorizationStatus.restricted {
            session?.stopRunning()
        }
    }
    
    func stopCamera() {
        if self.isRecording {
            self.toggleRecording()
        }
        
        session?.stopRunning()
    }
    
    @IBAction func shotButtonPressed(_ sender: UIButton) {
        self.toggleRecording()
    }
    
    @IBAction func flipButtonPressed(_ sender: UIButton) {
        
        guard let session = session else { return }
        
        session.stopRunning()
        
        do {
            session.beginConfiguration()
            for input in session.inputs {
                if let input = input as? AVCaptureInput {
                    session.removeInput(input)
                }
            }
            
            let position = videoInput?.device.position == AVCaptureDevicePosition.front ? AVCaptureDevicePosition.back : AVCaptureDevicePosition.front
            for device in AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) {
                if let device = device as? AVCaptureDevice,
                    device.position == position {
                    videoInput = try AVCaptureDeviceInput(device: device)
                    session.addInput(videoInput)
                }
            }
            
            session.commitConfiguration()
            
        } catch { }
        session.startRunning()
    }
    
    @IBAction func flashButtonPressed(_ sender: UIButton) {
        do {
            guard let device = device else { return }
            
            try device.lockForConfiguration()
            let mode = device.flashMode
            switch mode {
            case .off:
                device.flashMode = AVCaptureFlashMode.on
                flashButton.setImage(flashOnImage, for: UIControlState())
            case .on:
                device.flashMode = AVCaptureFlashMode.off
                flashButton.setImage(flashOffImage, for: UIControlState())
            default:
                break
            }
            
            device.unlockForConfiguration()
        } catch {
            flashButton.setImage(flashOffImage, for: UIControlState())
            return
        }
    }
    
    func resetVideoView() {
        startCamera()
        audioTimeCounter = 0.0
        videoProgressView?.progress = 0.0
        videoProgressView?.isHidden = true
    }
}

extension FSVideoCameraView: AVCaptureFileOutputRecordingDelegate {
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        print("started recording to: \(fileURL)")
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        print("finished recording to: \(outputFileURL)")
        self.delegate?.videoFinished(withFileURL: outputFileURL)
    }
}

fileprivate extension FSVideoCameraView {
    
    func toggleRecording() {
        
        guard let videoOutput = videoOutput else { return }
        self.isRecording = !self.isRecording
        let shotImage = self.isRecording ? videoStopImage : videoStartImage
        self.shotButton.setImage(shotImage, for: UIControlState())
        
        if self.isRecording {
            
            updateProgressView()
            shouldRotate = true
            rotateView(targetView: shotButton)
            
            let outputPath = "\(NSTemporaryDirectory())output.mov"
            let outputURL = URL(fileURLWithPath: outputPath)
            
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: outputPath) {
                
                do {
                    try fileManager.removeItem(atPath: outputPath)
                } catch {
                    print("error removing item at path: \(outputPath)")
                    self.isRecording = false
                    return
                }
            }
            
            self.flipButton.isEnabled = false
            self.flashButton.isEnabled = false
            videoOutput.startRecording(toOutputFileURL: outputURL, recordingDelegate: self)
            
        } else {
            stopTimer()
            shouldRotate = false
            videoOutput.stopRecording()
            self.flipButton.isEnabled = true
            self.flashButton.isEnabled = true
        }
    }
    
    @objc func focus(_ recognizer: UITapGestureRecognizer) {
        
        let point    = recognizer.location(in: self)
        let viewsize = self.bounds.size
        let newPoint = CGPoint(x: point.y / viewsize.height, y: 1.0-point.x / viewsize.width)
        
        guard let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) else { return }
        
        do {
            try device.lockForConfiguration()
        } catch _ {
            return
        }
        
        if device.isFocusModeSupported(AVCaptureFocusMode.autoFocus) == true {
            device.focusMode = AVCaptureFocusMode.autoFocus
            device.focusPointOfInterest = newPoint
        }
        
        if device.isExposureModeSupported(AVCaptureExposureMode.continuousAutoExposure) == true {
            device.exposureMode = AVCaptureExposureMode.continuousAutoExposure
            device.exposurePointOfInterest = newPoint
        }
        
        device.unlockForConfiguration()
        
        guard let focusView = focusView else { return }
        
        focusView.alpha  = 0.0
        focusView.center = point
        focusView.backgroundColor   = UIColor.clear
        focusView.layer.borderColor = UIColor.white.cgColor
        focusView.layer.borderWidth = 1.0
        focusView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        addSubview(focusView)
        
        UIView.animate(
            withDuration: 0.8,
            delay: 0.0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 3.0,
            options: UIViewAnimationOptions.curveEaseIn,
            animations: {
                focusView.alpha = 1.0
                focusView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        }, completion: {(finished) in
            focusView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            focusView.removeFromSuperview()
        })
    }
    
    func flashConfiguration() {
        do {
            guard let device = device else { return }
            try device.lockForConfiguration()
            device.flashMode = AVCaptureFlashMode.off
            flashButton.setImage(flashOffImage, for: UIControlState())
            device.unlockForConfiguration()
        } catch _ {
            return
        }
    }
    
    private func rotateView(targetView: UIView, duration: Double = 1.0) {
        UIView.animate(withDuration: duration, delay: 0.0, options: .curveLinear, animations: {
            targetView.transform = targetView.transform.rotated(by: CGFloat(Double.pi))
        }) { finished in
            if self.shouldRotate {
                self.rotateView(targetView: targetView, duration: duration)
            }
        }
    }
    
}

fileprivate extension FSVideoCameraView {
    
    func updateProgressView() {
        videoProgressView?.trackTintColor = .lightGray
        if !timerIsOn {
            timer = Timer.scheduledTimer(timeInterval: 0.0001, target: self, selector: #selector(timerRunning), userInfo: nil, repeats: true)
            timerIsOn = true
        }
    }
    
    @objc func timerRunning() {
        audioTimeCounter += 0.0001
        let completionPercentage = (audioTimeCounter * 100) / audioLimitTime
        videoProgressView?.setProgress(Float(completionPercentage / 100), animated: true)
        if audioTimeCounter >= audioLimitTime {
            stopTimer()
            toggleRecording()
        }
    }
    
    func stopTimer() {
        timer.invalidate()
        timerIsOn = false
    }
    
}
