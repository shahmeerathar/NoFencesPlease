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
    private var binaryEdgeMaps: [CIImage?] = Array(repeating: nil, count: 5)
    
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
        makeBinaryEdgeMaps()
        setDisplayImages()
        
        let initializer = Initializer(ciContext: self.ciContext)
        initializer.makeInitialGuesses(grays: grayscaleImages, edges: binaryEdgeMaps)
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
    
    func makeBinaryEdgeMaps() {
        for index in 0..<self.edgeMaps.count {
            makeBinaryEdgeMap(index: index)
        }
    }
    
    func makeBinaryEdgeMap(index: Int) {
        let rowBytes = Int(edgeMaps[index]!.extent.width)
        let dataSize = rowBytes * Int(edgeMaps[index]!.extent.height)
        let bitmapPointer = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 1)
        self.ciContext.render(edgeMaps[index]!, toBitmap: bitmapPointer, rowBytes: rowBytes, bounds: edgeMaps[index]!.extent, format: .R8, colorSpace: nil)
        
        let binaryBitmapPointer = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 1)
        
        for index in 0..<dataSize {
            let offsetPointer = bitmapPointer + index
            let value = offsetPointer.load(as: UInt8.self)
            
            var output: UInt8 = 0
            if value > 0 {
                output = 255
            }
            
            let binaryOffsetPointer = binaryBitmapPointer + index
            binaryOffsetPointer.storeBytes(of: output, as: UInt8.self)
        }
        
        let imageData = Data(bytesNoCopy: binaryBitmapPointer, count: dataSize, deallocator: .none)
        
        let binaryEdgeMap = CIImage(bitmapData: imageData, bytesPerRow: rowBytes, size: edgeMaps[index]!.extent.size, format: .R8, colorSpace: nil)
        
        binaryEdgeMaps[index] = binaryEdgeMap
    }
    
    func setDisplayImages() {
        for (index, img) in binaryEdgeMaps.enumerated() {
            if let cgimg = ciContext.createCGImage(img!, from: img!.extent) {
                display_images[index] = Image(cgimg, scale: 1.0, label: Text("Image \(index)"))
            }
        }
    }
}
