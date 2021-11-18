//
//  ImagesViewModel.swift
//  NoFencesPlease
//
//  Created by Muhammad Shahmeer Athar on 2021-11-08.
//

import Foundation
import CoreImage
import SwiftUI

class ImagesViewModel: ObservableObject {
    private var ciContext = CIContext()
    
    private var images: [CIImage?] = Array(repeating: nil, count: 5)
    private var grayscaleImages: [CIImage?] = Array(repeating: nil, count: 5)
    private var edgeMaps: [CIImage?] = Array(repeating: nil, count: 5)
    
    @Published var display_images: [Image?] = Array(repeating: nil, count: 5)
    
    func fetchImages() {
        // TODO: factor out into image retrieval classes
        let imgNames = ["hanoi_input_1", "hanoi_input_2", "hanoi_input_3", "hanoi_input_4", "hanoi_input_5"]
        
        for (index, imgName) in imgNames.enumerated() {
            let imgURL = Bundle.main.url(forResource: imgName, withExtension: "png")
            let img = CIImage(contentsOf: imgURL!)
            images[index] = img
        }
        
        removeObstruction()
    }
    
    func removeObstruction() {
        makeGrayscales()
        getEdgeMaps()
        setDisplayImages()
        
        let initializer = Initializer()
        initializer.makeInitialGuesses(grays: grayscaleImages, edges: edgeMaps)
    }
    
    func makeGrayscales() {
        let grayFilter = CIFilter(name:"CIPhotoEffectMono")
        for (index, img) in images.enumerated() {
            grayFilter?.setValue(img, forKey: kCIInputImageKey)
            grayscaleImages[index] = grayFilter?.outputImage
        }
    }
    
    func getEdgeMaps() {
        let edgeFilter = CIFilter(name: "CIEdges")
        for (index, img) in grayscaleImages.enumerated() {
            edgeFilter?.setValue(img, forKey: kCIInputImageKey)
            edgeMaps[index] = edgeFilter?.outputImage
        }
    }
    
    func setDisplayImages() {
        for (index, img) in edgeMaps.enumerated() {
            if let cgimg = ciContext.createCGImage(img!, from: img!.extent) {
                display_images[index] = Image(cgimg, scale: 1.0, label: Text("Image \(index)"))
            }
        }
    }
}
