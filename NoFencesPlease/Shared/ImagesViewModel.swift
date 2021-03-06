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
    private var output: [CIImage?] = Array(repeating: nil, count: 5)
    private var binaryEdgeCoordinates: [Array<[Int]>?] = Array(repeating: nil, count: 5)
    private var binaryEdgeCoordinatesSet: [Set<[Int]>?] = Array(repeating: nil, count: 5)
    
    let motionRadius = 7
    
    @Published var display_images: [Image?] = Array(repeating: nil, count: 5)
    
    func fetchImages() {
        // TODO: factor out into image retrieval classes
        print("Fetching images")
        let imgNames = ["hanoi_input_1", "hanoi_input_2", "hanoi_input_3", "hanoi_input_4", "hanoi_input_5"]
        
        for (index, imgName) in imgNames.enumerated() {
            let imgURL = Bundle.main.url(forResource: imgName, withExtension: "png")
            let img = CIImage(contentsOf: imgURL!)
            images[index] = img
        }
    }
    
    func removeObstruction() {
        makeGrayscales()
        getEdgeMaps()
        makeBinaryEdgeMaps()
        
        let initializer = Initializer(ciContext: ciContext, motionRadius: motionRadius)
        output = initializer.makeInitialGuesses(grays: grayscaleImages, edgeMaps: binaryEdgeMaps, edgeCoordinates: binaryEdgeCoordinates)
        
        setDisplayImages()
    }
    
    private func makeGrayscales() {
        let grayFilter = CIFilter(name:"CIPhotoEffectMono")
        for (index, img) in images.enumerated() {
            grayFilter?.setValue(img, forKey: kCIInputImageKey)
            grayscaleImages[index] = grayFilter?.outputImage
        }
    }
    
    private func getEdgeMaps() {
        let edgeFilter = CIFilter(name: "CIEdges")
        for (index, img) in grayscaleImages.enumerated() {
            edgeFilter?.setValue(img, forKey: kCIInputImageKey)
            edgeMaps[index] = edgeFilter?.outputImage
        }
    }
    
    private func makeBinaryEdgeMaps() {
        for index in 0..<edgeMaps.count {
            makeBinaryEdgeMap(index: index)
        }
    }
    
    private func makeBinaryEdgeMap(index: Int) {
        let numCols = Int(edgeMaps[index]!.extent.width)
        let numRows = Int(edgeMaps[index]!.extent.height)
        let numPixels = numRows * numCols
        
        let bitmapPointer = UnsafeMutableRawPointer.allocate(byteCount: numPixels, alignment: 1)
        self.ciContext.render(edgeMaps[index]!, toBitmap: bitmapPointer, rowBytes: numCols, bounds: edgeMaps[index]!.extent, format: .R8, colorSpace: nil)
        
        let binaryBitmapPointer = UnsafeMutableRawPointer.allocate(byteCount: numPixels, alignment: 1)
        var edgePoints = Array<[Int]>()
        var edgePointsSet = Set<[Int]>()
        
        for y in 0..<numRows {
            for x in 0..<numCols {
                let index = (y * numCols) + x
                let offsetPointer = bitmapPointer + index
                let value = offsetPointer.load(as: UInt8.self)
                
                let yRange = motionRadius..<(numRows - motionRadius)
                let xRange = motionRadius..<(numCols - motionRadius)
                
                var output: UInt8 = 0
                if value > 0 {
                    output = 255
                    
                    // Padding
                    if yRange.contains(y) && xRange.contains(x) {
                        let edgePoint = [y, x]
                        edgePoints.append(edgePoint)
                        edgePointsSet.insert(edgePoint)
                    }
                }
                
                let binaryOffsetPointer = binaryBitmapPointer + index
                binaryOffsetPointer.storeBytes(of: output, as: UInt8.self)
            }
        }
        
        let imageData = Data(bytesNoCopy: binaryBitmapPointer, count: numPixels, deallocator: .none)
        
        let binaryEdgeMap = CIImage(bitmapData: imageData, bytesPerRow: numCols, size: edgeMaps[index]!.extent.size, format: .R8, colorSpace: nil)
        
        binaryEdgeMaps[index] = binaryEdgeMap
        binaryEdgeCoordinates[index] = edgePoints
        binaryEdgeCoordinatesSet[index] = edgePointsSet
    }
    
    private func setDisplayImages() {
        for (index, img) in output.enumerated() {
            if img == nil {
                continue
            }
            if let cgimg = ciContext.createCGImage(img!, from: img!.extent) {
                display_images[index] = Image(cgimg, scale: 1.0, label: Text("Image \(index)"))
            }
        }
    }
}
