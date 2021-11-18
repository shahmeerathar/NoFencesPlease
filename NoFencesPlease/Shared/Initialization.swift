//
//  Initialization.swift
//  NoFencesPlease
//
//  Created by Muhammad Shahmeer Athar on 2021-11-16.
//

import Foundation
import CoreImage

class Initializer {
    private var ciContext: CIContext
    
    init(ciContext: CIContext) {
        self.ciContext = ciContext
    }
    
    func makeInitialGuesses(grays: [CIImage?], edges: [CIImage?]) {
//        var initialObstructions = nil
//        var initialBackground = nil
//        var initialAlpha = nil
//        var obstructionMotions = nil
//        var backgroundMotions = nil
        
        var edgeFlows: [CIImage?] = Array(repeating: nil, count: grays.count)
        let refFrameIndex = grays.count / 2
        
        for index in 0..<grays.count {
            if (index != refFrameIndex) {
                let edgeFlow = calculateEdgeFlow(referenceImageGray: grays[refFrameIndex]!, comparisonImageGray: grays[index]!, referenceImageEdges: edges[refFrameIndex]!, comparisonImageEdges: edges[index]!)
                edgeFlows[index] = edgeFlow
            }
        }
    }
    
    private func calculateEdgeFlow(referenceImageGray: CIImage, comparisonImageGray: CIImage, referenceImageEdges: CIImage, comparisonImageEdges: CIImage) -> CIImage {
        let edgeFlow = CIImage()
        
        return edgeFlow
    }
}
