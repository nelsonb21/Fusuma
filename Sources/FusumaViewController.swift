//
//  FusumaViewController.swift
//  Fusuma
//
//  Created by Yuta Akizuki on 2015/11/14.
//  Copyright © 2015年 ytakzk. All rights reserved.
//

import UIKit
import Photos

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}

public protocol FusumaDelegate: class {
    
    func fusumaImageSelected(_ image: UIImage, source: FusumaMode)
    func fusumaMultipleImageSelected(_ images: [UIImage], source: FusumaMode)
    func fusumaVideoCompleted(withFileURL fileURL: URL)
    func fusumaCameraRollUnauthorized()
    
    // optional
    func fusumaImageSelected(_ image: UIImage, source: FusumaMode, metaData: ImageMetadata)
    func fusumaDismissedWithImage(_ image: UIImage, source: FusumaMode)
    func fusumaClosed()
    func fusumaWillClosed()
}

public extension FusumaDelegate {
    
    func fusumaImageSelected(_ image: UIImage, source: FusumaMode, metaData: ImageMetadata) {}
    func fusumaDismissedWithImage(_ image: UIImage, source: FusumaMode) {}
    func fusumaClosed() {}
    func fusumaWillClosed() {}
}

public var fusumaBaseTintColor   = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0) //UIColor.hex("#FFFFFF", alpha: 1.0)
public var fusumaTintColor       = #colorLiteral(red: 0.631372549, green: 0.7411764706, blue: 1, alpha: 1) //UIColor.hex("#F38181", alpha: 1.0)
public var fusumaBackgroundColor = UIColor.hex("#3B3D45", alpha: 1.0)

public var fusumaAlbumImage: UIImage?
public var fusumaCameraImage: UIImage?
public var fusumaVideoImage: UIImage?
public var fusumaCheckImage: UIImage?
public var fusumaCloseImage: UIImage?
public var fusumaFlashOnImage: UIImage?
public var fusumaFlashOffImage: UIImage?
public var fusumaFlipImage: UIImage?
public var fusumaShotImage: UIImage?

public var fusumaVideoStartImage: UIImage?
public var fusumaVideoStopImage: UIImage?

public var fusumaCropImage: Bool  = true

public var fusumaSavesImage: Bool = false

public var fusumaCameraRollTitle = "CAMERA ROLL"
public var fusumaCameraTitle     = "PHOTO"
public var fusumaVideoTitle      = "VIDEO"
public var fusumaTitleFont       = UIFont(name: "AvenirNext-DemiBold", size: 15)

public var fusumaTintIcons: Bool = true

@objc public enum FusumaMode: Int {
    
    case camera
    case library
    case video
    case none
}

public struct ImageMetadata {
    public let mediaType: PHAssetMediaType
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let creationDate: Date?
    public let modificationDate: Date?
    public let location: CLLocation?
    public let duration: TimeInterval
    public let isFavourite: Bool
    public let isHidden: Bool
}

@objc public class FusumaViewController: UIViewController {

    public var hasVideo = false
    public var cropHeightRatio: CGFloat = 1
    public var allowMultipleSelection: Bool = false

    fileprivate var mode: FusumaMode = .none
    public var defaultMode: FusumaMode = .library
    fileprivate var willFilter = true

    @IBOutlet weak var photoLibraryViewerContainer: UIView!
    @IBOutlet weak var cameraShotContainer: UIView!
    @IBOutlet weak var videoShotContainer: UIView!

    @IBOutlet weak var libraryButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var videoButton: UIButton!

    //@IBOutlet var libraryFirstConstraints: [NSLayoutConstraint]!
    //@IBOutlet var cameraFirstConstraints: [NSLayoutConstraint]!
    
    lazy var albumView  = FSAlbumView.instance()
    public lazy var cameraView = FSCameraView.instance()
    lazy var videoView  = FSVideoCameraView.instance()

    fileprivate var hasGalleryPermission: Bool {
        return PHPhotoLibrary.authorizationStatus() == .authorized
    }
    
    public weak var delegate: FusumaDelegate? = nil
    
    override public func loadView() {
        if let view = UINib(nibName: "FusumaViewController", bundle: Bundle(for: self.classForCoder)).instantiate(withOwner: self, options: nil).first as? UIView {
            self.view = view
        }
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
    
        view.backgroundColor = fusumaBackgroundColor
        
        cameraView.delegate = self
        albumView.delegate  = self
        videoView.delegate  = self

        albumView.allowMultipleSelection = allowMultipleSelection
        
        let bundle = Bundle(for: self.classForCoder)
        
        // Get the custom button images if they're set
        let albumImage = fusumaAlbumImage != nil ? fusumaAlbumImage : UIImage(named: "ic_insert_photo", in: bundle, compatibleWith: nil)
        let cameraImage = fusumaCameraImage != nil ? fusumaCameraImage : UIImage(named: "ic_photo_camera", in: bundle, compatibleWith: nil)
        let videoImage = fusumaVideoImage != nil ? fusumaVideoImage : UIImage(named: "ic_videocam", in: bundle, compatibleWith: nil)

        if fusumaTintIcons {
            
            let albumImage  = albumImage?.withRenderingMode(.alwaysTemplate)
            let cameraImage = cameraImage?.withRenderingMode(.alwaysTemplate)
            let videoImage  = videoImage?.withRenderingMode(.alwaysTemplate)

            libraryButton.setImage(albumImage, for: UIControlState())
            libraryButton.setImage(albumImage, for: .highlighted)
            libraryButton.setImage(albumImage, for: .selected)
            libraryButton.tintColor = fusumaTintColor
            libraryButton.adjustsImageWhenHighlighted = false

            cameraButton.setImage(cameraImage, for: UIControlState())
            cameraButton.setImage(cameraImage, for: .highlighted)
            cameraButton.setImage(cameraImage, for: .selected)
            cameraButton.tintColor = fusumaTintColor
            cameraButton.adjustsImageWhenHighlighted = false
            
            videoButton.setImage(videoImage, for: UIControlState())
            videoButton.setImage(videoImage, for: .highlighted)
            videoButton.setImage(videoImage, for: .selected)
            videoButton.tintColor = fusumaTintColor
            videoButton.adjustsImageWhenHighlighted = false
        } else {
            libraryButton.setImage(albumImage, for: UIControlState())
            libraryButton.setImage(albumImage, for: .highlighted)
            libraryButton.setImage(albumImage, for: .selected)
            libraryButton.tintColor = nil
            
            cameraButton.setImage(cameraImage, for: UIControlState())
            cameraButton.setImage(cameraImage, for: .highlighted)
            cameraButton.setImage(cameraImage, for: .selected)
            cameraButton.tintColor = nil

            videoButton.setImage(videoImage, for: UIControlState())
            videoButton.setImage(videoImage, for: .highlighted)
            videoButton.setImage(videoImage, for: .selected)
            videoButton.tintColor = nil
        }
        
        cameraButton.clipsToBounds  = true
        libraryButton.clipsToBounds = true
        videoButton.clipsToBounds   = true
        
        photoLibraryViewerContainer.addSubview(albumView)
        cameraShotContainer.addSubview(cameraView)
        videoShotContainer.addSubview(videoView)
        
        if fusumaCropImage {
            let heightRatio = getCropHeightRatio()
            
            cameraView.croppedAspectRatioConstraint = NSLayoutConstraint(
                item: cameraView.previewViewContainer,
                attribute: NSLayoutAttribute.height,
                relatedBy: NSLayoutRelation.equal,
                toItem: cameraView.previewViewContainer,
                attribute: NSLayoutAttribute.width,
                multiplier: heightRatio,
                constant: 0)

            cameraView.fullAspectRatioConstraint?.isActive    = false
            cameraView.croppedAspectRatioConstraint?.isActive = true
        } else {
            cameraView.fullAspectRatioConstraint?.isActive    = true
            cameraView.croppedAspectRatioConstraint?.isActive = false
        }
        
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        albumView.frame  = CGRect(origin: CGPoint.zero, size: photoLibraryViewerContainer.frame.size)
        albumView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cameraView.frame = CGRect(origin: CGPoint.zero, size: cameraShotContainer.frame.size)
        cameraView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        albumView.initialize()
        cameraView.initialize()
        
        if hasVideo {
            videoView.frame = CGRect(origin: CGPoint.zero, size: videoShotContainer.frame.size)
            videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            videoView.initialize()
        }
        
        changeMode(defaultMode)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopAll()
    }

    override public var prefersStatusBarHidden : Bool {
        return false
    }
    
    public func closeButtonPressed() {
        self.delegate?.fusumaWillClosed()
        self.delegate?.fusumaClosed()
    }
    
    @IBAction func libraryButtonPressed(_ sender: UIButton) {
        changeMode(FusumaMode.library)
    }
    
    @IBAction func photoButtonPressed(_ sender: UIButton) {
        changeMode(FusumaMode.camera)
    }
    
    @IBAction func videoButtonPressed(_ sender: UIButton) {
        changeMode(FusumaMode.video)
    }
    
    public func doneButtonPressed() {
        allowMultipleSelection ? fusumaDidFinishInMultipleMode() : fusumaDidFinishInSingleMode()
    }
    
    private func fusumaDidFinishInSingleMode() {
        guard let view = albumView.imageCropView else { return }
        
        if !fusumaCropImage {
            let normalizedX = view.contentOffset.x / view.contentSize.width
            let normalizedY = view.contentOffset.y / view.contentSize.height
            let normalizedWidth  = view.frame.width / view.contentSize.width
            let normalizedHeight = view.frame.height / view.contentSize.height
            
            let cropRect = CGRect(x: normalizedX, y: normalizedY,
                                  width: normalizedWidth, height: normalizedHeight)
            
            requestImage(with: self.albumView.phAsset, cropRect: cropRect) { (asset, image) in
                self.delegate?.fusumaImageSelected(image, source: self.mode)
                
                let metaData = ImageMetadata(
                    mediaType: self.albumView.phAsset.mediaType,
                    pixelWidth: self.albumView.phAsset.pixelWidth,
                    pixelHeight: self.albumView.phAsset.pixelHeight,
                    creationDate: self.albumView.phAsset.creationDate,
                    modificationDate: self.albumView.phAsset.modificationDate,
                    location: self.albumView.phAsset.location,
                    duration: self.albumView.phAsset.duration,
                    isFavourite: self.albumView.phAsset.isFavorite,
                    isHidden: self.albumView.phAsset.isHidden)
                
                self.delegate?.fusumaImageSelected(image, source: self.mode, metaData: metaData)
            }
            
        } else {
            print("no image crop ")
            delegate?.fusumaImageSelected(view.image, source: mode)
            delegate?.fusumaDismissedWithImage(view.image, source: self.mode)
        }
    }
    
    private func requestImage(with asset: PHAsset, cropRect: CGRect, completion: @escaping (PHAsset, UIImage) -> Void) {
        
        DispatchQueue.global(qos: .default).async(execute: {
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.normalizedCropRect = cropRect
            options.resizeMode = .exact
            
            let targetWidth  = floor(CGFloat(asset.pixelWidth) * cropRect.width)
            let targetHeight = floor(CGFloat(asset.pixelHeight) * cropRect.height)
            let dimensionW   = max(min(targetHeight, targetWidth), 1024 * UIScreen.main.scale)
            let dimensionH   = dimensionW * self.getCropHeightRatio()
            let targetSize   = CGSize(width: dimensionW, height: dimensionH)
            
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { result, info in
                guard let result = result else { return }
                DispatchQueue.main.async(execute: {
                    completion(asset, result)
                })
            }
        })
    }
    
    private func fusumaDidFinishInMultipleMode() {
        guard let view = albumView.imageCropView else { return }
        let normalizedX = view.contentOffset.x / view.contentSize.width
        let normalizedY = view.contentOffset.y / view.contentSize.height
        let normalizedWidth  = view.frame.width / view.contentSize.width
        let normalizedHeight = view.frame.height / view.contentSize.height
        let cropRect = CGRect(x: normalizedX, y: normalizedY, width: normalizedWidth, height: normalizedHeight)
        var images = [UIImage]()
        
        for asset in albumView.selectedAssets {
            requestImage(with: asset, cropRect: cropRect) { asset, result in
                images.append(result)
                
                if asset == self.albumView.selectedAssets.last {
                    if let _ = self.delegate?.fusumaMultipleImageSelected {
                        self.delegate?.fusumaMultipleImageSelected(images, source: self.mode)
                    }
                }
            }
        }
    }
    
    public func stopAll() {
        if hasVideo {
            videoView.stopCamera()
        }
        cameraView.stopCamera()
    }
}

extension FusumaViewController: FSAlbumViewDelegate, FSCameraViewDelegate, FSVideoCameraViewDelegate {
    
    public func getCropHeightRatio() -> CGFloat {
        return cropHeightRatio
    }
    
    // MARK: FSCameraViewDelegate
    func cameraShotFinished(_ image: UIImage) {
        delegate?.fusumaImageSelected(image, source: mode)
        delegate?.fusumaDismissedWithImage(image, source: self.mode)
    }
    
    public func albumViewCameraRollAuthorized() {
        // in the case that we're just coming back from granting photo gallery permissions
        // ensure the done button is visible if it should be
        updateDoneButtonVisibility()
    }
    
    // MARK: FSAlbumViewDelegate
    public func albumViewCameraRollUnauthorized() {
        delegate?.fusumaCameraRollUnauthorized()
    }
    
    func videoFinished(withFileURL fileURL: URL) {
        videoView.resetVideoView()
        delegate?.fusumaVideoCompleted(withFileURL: fileURL)
    }
    
}

private extension FusumaViewController {
    
    func changeMode(_ mode: FusumaMode) {
        if self.mode == mode { return }
        
        //operate this switch before changing mode to stop cameras
        switch self.mode {
        case .camera:
            cameraView.stopCamera()
        case .video:
            videoView.stopCamera()
        default:
            break
        }
        
        self.mode = mode
        
        dishighlightButtons()
        updateDoneButtonVisibility()
        
        switch mode {
        case .library:
            highlightButton(libraryButton)
            view.bringSubview(toFront: photoLibraryViewerContainer)
            photoLibraryViewerContainer.isHidden = false
            cameraShotContainer.isHidden = true
            videoShotContainer.isHidden = true
            
        case .camera:
            highlightButton(cameraButton)
            view.bringSubview(toFront: cameraShotContainer)
            cameraView.startCamera()
            cameraShotContainer.isHidden = false
            photoLibraryViewerContainer.isHidden = false
            videoShotContainer.isHidden = true
            
        case .video:
            highlightButton(videoButton)
            view.bringSubview(toFront: videoShotContainer)
            videoView.startCamera()
            videoView.videoTimeCounter = 0.0
            videoView.videoProgressView?.progress = 0.0
            videoShotContainer.isHidden = false
            photoLibraryViewerContainer.isHidden = false
            cameraShotContainer.isHidden = true
            
        default:
            break
        }
    }
    
    func updateDoneButtonVisibility() {
        // don't show the done button without gallery permission
        if !hasGalleryPermission {
            return
        }

        switch self.mode {
        case .library:
            break
        default:
            break
        }
    }
    
    func dishighlightButtons() {
        cameraButton.tintColor  = fusumaBaseTintColor
        libraryButton.tintColor = fusumaBaseTintColor
        videoButton.tintColor = fusumaBaseTintColor

        if cameraButton.layer.sublayers?.count > 1,
            let sublayers = cameraButton.layer.sublayers {
            
            for layer in sublayers {
                if let borderColor = layer.borderColor,
                    UIColor(cgColor: borderColor) == fusumaTintColor {
                    layer.removeFromSuperlayer()
                }
            }
        }
        
        if libraryButton.layer.sublayers?.count > 1,
            let sublayers = libraryButton.layer.sublayers {
            
            for layer in sublayers {
                if let borderColor = layer.borderColor,
                    UIColor(cgColor: borderColor) == fusumaTintColor {
                    layer.removeFromSuperlayer()
                }
            }
        }
        
        if let videoButton = videoButton,
            videoButton.layer.sublayers?.count > 1,
            let sublayers = videoButton.layer.sublayers {
            
            videoButton.tintColor = fusumaBaseTintColor
            
            for layer in sublayers {
                if let borderColor = layer.borderColor,
                    UIColor(cgColor: borderColor) == fusumaTintColor {
                    layer.removeFromSuperlayer()
                }
            }
        }
    }
    
    func highlightButton(_ button: UIButton) {
        button.tintColor = fusumaTintColor
        button.addBottomBorder(fusumaTintColor, width: 3)
    }
}
