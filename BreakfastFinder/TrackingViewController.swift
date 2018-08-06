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
    
    @IBOutlet weak var previewView: UIImageView!
    
    private var workQueue = DispatchQueue(label: "TrackingViewController", qos: .userInitiated)
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupCoreMLRequest()
        
        previewView.contentMode = .scaleAspectFit
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.startRenderVideo()
    }
    
    func startRenderVideo() {
        workQueue.async {
            guard let videoReader = VideoReader(videoAsset: self.videoAsset) else { return }
            
            while true {
                guard let imageBuffer = videoReader.nextFrame() else { break }
                
                self.classifyFrame(image: imageBuffer)
                
                let image: UIImage = self.convert(cmage: CIImage(cvPixelBuffer: imageBuffer))
                
                DispatchQueue.main.async {
                    self.previewView.image = image
                }
            }
        }
    }
    
    func convert(cmage:CIImage) -> UIImage {
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        
        return image
    }

    // CoreML logic
    
    var coreMLRequest: VNRequest!
    
    func setupCoreMLRequest() {
        if let model = try? VNCoreMLModel(for: ObjectDetector().model) {
            coreMLRequest = VNCoreMLRequest(model: model, completionHandler: { (request, error) in
                guard let results = request.results as? [VNRecognizedObjectObservation] else {
                    fatalError("error")
                }
                
                for result in results {
                    print(result.labels.first!)
                }
            })
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
    
}
