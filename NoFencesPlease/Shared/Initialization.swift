//
//  Initialization.swift
//  NoFencesPlease
//
//  Created by Muhammad Shahmeer Athar on 2021-11-16.
//

import Foundation
import CoreImage

enum Direction: Int, CaseIterable {
    // Raw value defines index in messages for MRFNode
    case left = 0
    case up = 1
    case right = 2
    case down = 3
}

struct MRFNode {
    let observableValue: Int
    var bestLabel: Int
    var messages: [[[Int]]] // Direction, then nested labels in grid by index
    
    init(motionRadius: Int) {
        let motionDiameter = (motionRadius * 2) + 1
        
        observableValue = 0
        bestLabel = 0
        messages = Array(repeating: Array(repeating: Array(repeating: 0, count: motionDiameter), count: motionDiameter), count: 4)
    }
}

struct MarkovRandomField {
    let nodes: [[MRFNode]]
    
    init(width: Int, height: Int, motionRadius: Int) {
        nodes = Array(repeating: Array(repeating: MRFNode(motionRadius: motionRadius), count: width), count: height)
    }
}

struct MotionField {
    
}

class Initializer {
    private var ciContext: CIContext
    private let patchRadius = 2
    private let motionRadius = 15
    private let numBeliefPropagationIterations = 40
    
    init(ciContext: CIContext) {
        self.ciContext = ciContext
    }
    
    func makeInitialGuesses(grays: [CIImage?], edges: [CIImage?]) {
//        var initialObstructions = nil
//        var initialBackground = nil
//        var initialAlpha = nil
//        var obstructionMotions = nil
//        var backgroundMotions = nil
        
        var edgeFlows: [MotionField?] = Array(repeating: nil, count: grays.count)
        let refFrameIndex = grays.count / 2
        
        for index in 0..<grays.count {
            if (index != refFrameIndex) {
                let edgeFlow = calculateEdgeFlow(referenceImageGray: grays[refFrameIndex]!,
                                                 comparisonImageGray: grays[index]!,
                                                 referenceImageEdges: edges[refFrameIndex]!,
                                                 comparisonImageEdges: edges[index]!)
                edgeFlows[index] = edgeFlow
            }
        }
    }
    
    private func calculateEdgeFlow(referenceImageGray: CIImage, comparisonImageGray: CIImage, referenceImageEdges: CIImage, comparisonImageEdges: CIImage) -> CIImage {
        let edgeFlow = CIImage()
        
        return edgeFlow
    }
}
