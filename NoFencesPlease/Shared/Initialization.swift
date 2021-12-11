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
        // message at index [][motionRadius][motionRadius] should be ignored because zero offset
        // offset = directionalLabel - motionRadius
        messages = Array(repeating: Array(repeating: Array(repeating: 0, count: motionDiameter), count: motionDiameter), count: Direction.allCases.count)
    }
}

struct MarkovRandomField {
    var width: Int
    var height: Int
    var nodes: [[MRFNode]]
    
    init(width: Int, height: Int, motionRadius: Int) {
        self.width = width
        self.height = height
        nodes = Array(repeating: Array(repeating: MRFNode(motionRadius: motionRadius), count: width), count: height)
    }
}

struct MotionField {
    // TODO: Implement struct
}

class Initializer {
    private var ciContext: CIContext
    private let motionRadius: Int
    private let motionDiameter: Int
    private let patchRadius = 2
    private let numBeliefPropagationIterations = 40
    
    init(ciContext: CIContext, motionRadius: Int) {
        self.ciContext = ciContext
        self.motionRadius = motionRadius
        self.motionDiameter = (motionRadius * 2) + 1
    }
    
    func makeInitialGuesses(grays: [CIImage?], edgeCoordinates: [Set<[Int]>?]) {
//        var initialObstructions = nil
//        var initialBackground = nil
//        var initialAlpha = nil
//        var obstructionMotions = nil
//        var backgroundMotions = nil
        
        var edgeFlows: [MotionField?] = Array(repeating: nil, count: grays.count)
        let refFrameIndex = grays.count / 2
        
        for index in 0..<grays.count {
            if (index != refFrameIndex) {
                print("Calculating edge flow for image \(index)")
                // These edge flows should be *from* an image to the reference image
                edgeFlows[index] = beliefPropagation(edgeCoordinates: edgeCoordinates[index]!, image: grays[index]!, referenceImageGray: grays[refFrameIndex]!)
            }
        }
    }
    
    func getLabelOffset(label: Int) -> Int {
        return label - motionRadius
    }
    
    // MARK: Functions for loopy belief propagation
    
    private func calculateDataCost(image: CIImage, imageY: Int, imageX: Int, refImage: CIImage, refImageY: Int, refImageX: Int) -> Int {
        // TODO: Implement NCC
        return 1
    }
    
    private func calculateSmoothnessCost() -> Int {
        // TODO: Implement w12 cost
        return 0
    }
    
    private func beliefPropagation(edgeCoordinates: Set<[Int]>, image: CIImage, referenceImageGray: CIImage) -> MotionField {
        var MRF = MarkovRandomField(width: Int(referenceImageGray.extent.size.width),
                                    height: Int(referenceImageGray.extent.size.height),
                                    motionRadius: motionRadius)
        
        for round in 0..<numBeliefPropagationIterations {
            print("Initiating message passing round \(round)")
            for direction in Direction.allCases {
                print("Sending messages \(direction)")
                MRF = messagePassingRound(previousMRF: MRF, direction: direction, edgeCoordinates: edgeCoordinates, image: image, refImage: referenceImageGray)
            }
        }
        
        return findBestLabelling(MRF: MRF)
    }
    
    private func messagePassingRound(previousMRF: MarkovRandomField, direction: Direction, edgeCoordinates: Set<[Int]>, image: CIImage, refImage: CIImage) -> MarkovRandomField {
        var newMRF = MarkovRandomField(width: previousMRF.width, height: previousMRF.height, motionRadius: motionRadius)
        
        for (index, edgeCoordinate) in edgeCoordinates.enumerated() {
            let yCoord = edgeCoordinate[0]
            let xCoord = edgeCoordinate[1]
            print("Coordinates: \(edgeCoordinate) (\(index + 1) of \(edgeCoordinates.count))")
            sendMessage(previousMRF: previousMRF, newMRF: &newMRF, y: yCoord, x: xCoord, direction: direction, edgeCoordinates: edgeCoordinates, image: image, refImage: refImage)
        }
        
        return newMRF
    }
    
    private func sendMessage(previousMRF: MarkovRandomField, newMRF: inout MarkovRandomField, y: Int, x: Int, direction: Direction, edgeCoordinates: Set<[Int]>, image: CIImage, refImage: CIImage) {
        var newMessage = Array(repeating: Array(repeating: 0, count: motionDiameter), count: motionDiameter)
        
        for yLabelOuter in 0..<motionDiameter {
            for xLabelOuter in 0..<motionDiameter {
                var minCost = Int.max
                
                for yLabelInner in 0..<motionDiameter {
                    for xLabelInner in 0..<motionDiameter {
                        let yOffset = getLabelOffset(label: yLabelOuter)
                        let xOffset = getLabelOffset(label: xLabelOuter)
                        
                        var cost = calculateDataCost(image: image, imageY: y, imageX: x, refImage: refImage, refImageY: y + yOffset, refImageX: x + xOffset)
                        cost += calculateSmoothnessCost()
                        let node = previousMRF.nodes[y][x]
                        
                        for directionCase in Direction.allCases {
                            if direction != directionCase {
                                cost += node.messages[directionCase.rawValue][yLabelInner][xLabelInner]
                            }
                        }
                        
                        minCost = min(minCost, cost)
                    }
                }
                
                newMessage[yLabelOuter][xLabelOuter] = minCost
            }
        }
        
        switch direction {
        case .left:
            newMRF.nodes[y][x - 1].messages[Direction.right.rawValue] = newMessage
        case .up:
            newMRF.nodes[y - 1][x].messages[Direction.down.rawValue] = newMessage
        case .right:
            newMRF.nodes[y][x + 1].messages[Direction.left.rawValue] = newMessage
        case .down:
            newMRF.nodes[y + 1][x].messages[Direction.up.rawValue] = newMessage
        }
    }
    
    private func findBestLabelling(MRF: MarkovRandomField) -> MotionField {
        // TODO: Find best label for pixel
        return MotionField()
    }
}
