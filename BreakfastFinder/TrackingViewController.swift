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
                
                let ciimage: CIImage = CIImage(cvPixelBuffer: imageBuffer)
                
                let image: UIImage = self.convert(cmage: ciimage)
                
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
    
}
