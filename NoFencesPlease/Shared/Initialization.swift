//
//  Initialization.swift
//  NoFencesPlease
//
//  Created by Muhammad Shahmeer Athar on 2021-11-16.
//

import Foundation
import CoreImage

class Initializer {
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
                let edgeFlow = calculateEdgeFlow()
                edgeFlows[index] = edgeFlow
            }
        }
    }
    
    private func calculateEdgeFlow() -> CIImage {
        let edgeFlow = CIImage()
        
        return edgeFlow
    }
}
