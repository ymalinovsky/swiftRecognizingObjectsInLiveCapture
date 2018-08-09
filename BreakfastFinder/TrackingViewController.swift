//
//  TrackingViewController.swift
//  BreakfastFinder
//
//  Created by Yan Malinovsky on 01.08.2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class TrackingViewController: UIViewController {

    var videoAsset: AVAsset!
    
    private var detectionOverlay: CALayer! = nil
    
    @IBOutlet weak var previewView: UIImageView!
    var rootLayer: CALayer! = nil
    
    private var workQueue = DispatchQueue(label: "TrackingViewController", qos: .userInitiated)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        rootLayer = previewView.layer
        
        self.setupLayers()
        self.updateLayerGeometry()
        self.setupCoreMLRequest()
        
        previewView.contentMode = .scaleAspectFit
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.startRenderVideo()
    }
    
    func getImageBufferSize() -> CGSize {
        if let image = previewView.image {
            let widthRatio = previewView.frame.size.width / image.size.width
            let heightRatio = previewView.frame.size.height / image.size.height
            let scale = min(widthRatio, heightRatio)
            let imageWidth = scale * image.size.width
            let imageHeight = scale * image.size.height
            
            return CGSize(width: imageWidth, height: imageHeight)
        }

        return CGSize.zero
    }
    
    func startRenderVideo() {
        workQueue.async {
            guard let videoReader = VideoReader(videoAsset: self.videoAsset) else { return }
            
            while true {
                guard let imageBuffer = videoReader.nextFrame() else { break }
        
                let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                
                self.classifyFrame(image: imageBuffer)
                
                let image: UIImage = self.convert(ciImage: ciImage)
                
                DispatchQueue.main.async {
                    self.previewView.image = image
                }
            }
        }
    }
    
    func convert(ciImage:CIImage) -> UIImage {
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(ciImage, from: ciImage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        
        return image
    }
    
    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / getImageBufferSize().height
        let yScale: CGFloat = bounds.size.height / getImageBufferSize().width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        detectionOverlay.position = CGPoint (x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
        
    }
    
    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\nConfidence:  %.2f", confidence))
        let largeFont = UIFont(name: "Helvetica", size: 24.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.height - 10, height: bounds.size.width - 10)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        textLayer.contentsScale = 2.0 // retina rendering
        // rotate the layer into screen orientation and scale and mirror
        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
        return textLayer
    }
    
    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 0.2, 0.4])
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }

    // CoreML logic
    
    var coreMLRequest: VNCoreMLRequest!
    
    func setupCoreMLRequest() {
        if let model = try? VNCoreMLModel(for: ImageClassifier().model) {
            coreMLRequest = VNCoreMLRequest(model: model, completionHandler: { (request, error) in
                DispatchQueue.main.async(execute: {
                    // perform all the UI updates on the main queue
                    if let results = request.results {
                        self.drawImageRequestResults(results)
                    }
                })
            })
            
            coreMLRequest.usesCPUOnly = true
            
            coreMLRequest.imageCropAndScaleOption = .centerCrop
        }
    }
    
    func classifyFrame(image: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .up)
        
        do {
            try handler.perform([coreMLRequest])
        } catch {
            fatalError("error")
        }
    }
    
    func drawImageRequestResults(_ results: [Any]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil // remove all the old recognized objects
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            
            // Select only the label with the highest confidence.
            let topLabelObservation = objectObservation.labels[0]
            
            if topLabelObservation.confidence > 0.90 {
                let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(getImageBufferSize().width), Int(getImageBufferSize().height))
                
                let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
                
                let textLayer = self.createTextSubLayerInBounds(objectBounds,
                                                                identifier: topLabelObservation.identifier,
                                                                confidence: topLabelObservation.confidence)
                shapeLayer.addSublayer(textLayer)
                detectionOverlay.addSublayer(shapeLayer)
            }
            
            break
        }
        self.updateLayerGeometry()
        CATransaction.commit()
    }
    
    func setupLayers() {
        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = self.previewView.frame
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
    }
}
