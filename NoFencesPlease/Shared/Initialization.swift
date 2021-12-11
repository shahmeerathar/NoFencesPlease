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
                let edgeFlow = calculateEdgeFlow(referenceImageGray: grays[refFrameIndex]!,
                                                 comparisonImageGray: grays[index]!,
                                                 comparisonImageEdges: edgeCoordinates[index]!)
                edgeFlows[index] = edgeFlow
            }
        }
    }
    
    private func calculateEdgeFlow(referenceImageGray: CIImage, comparisonImageGray: CIImage, comparisonImageEdges: Set<[Int]>) -> MotionField {
        // Edge flow = motion field from referenceImageEdges to comparisonImageEdges
        let edgeFlow = MotionField()
        var MRF = MarkovRandomField(width: Int(referenceImageGray.extent.size.width),
                                    height: Int(referenceImageGray.extent.size.height),
                                    motionRadius: motionRadius)
        beliefPropagation(MRF: &MRF, motionField: edgeFlow, edgeCoordinates: comparisonImageEdges)
        
        return edgeFlow
    }
    
    private func calculateDataCost() -> Int {
        // TODO: Implement NCC
        return 0
    }
    
    private func calculateSmoothnessCost() -> Int {
        // TODO: Implement w12 cost
        return 0
    }
    
    private func beliefPropagation(MRF: inout MarkovRandomField, motionField: MotionField, edgeCoordinates: Set<[Int]>) {
        // TODO: Implement loopy BP algorithm
        for round in 0..<numBeliefPropagationIterations {
            print("Initiating message passing round \(round)")
            for direction in Direction.allCases {
                print("Sending messages \(direction)")
                messagePassingRound(MRF: &MRF, direction: direction, edgeCoordinates: edgeCoordinates)
            }
        }
        
        findBestLabelling()
    }
    
    private func messagePassingRound(MRF: inout MarkovRandomField, direction: Direction, edgeCoordinates: Set<[Int]>) {
        for edgeCoordinate in edgeCoordinates {
            let yCoord = edgeCoordinate[0]
            let xCoord = edgeCoordinate[1]
            // print("Coordinates: \(edgeCoordinate) (\(index + 1) of \(edgeCoordinates.count))")
            sendMessage(MRF: &MRF, y: yCoord, x: xCoord, direction: direction, edgeCoordinates: edgeCoordinates)
        }
    }
    
    private func sendMessage(MRF: inout MarkovRandomField, y: Int, x: Int, direction: Direction, edgeCoordinates: Set<[Int]>) {
        var newMessage = Array(repeating: Array(repeating: 0, count: motionDiameter), count: motionDiameter)
        
        for yLabelOuter in 0..<motionDiameter {
            for xLabelOuter in 0..<motionDiameter {
                var minCost = Int.max
                
                for yLabelInner in 0..<motionDiameter {
                    for xLabelInner in 0..<motionDiameter {
                        var cost = 0
                        
                        cost += calculateSmoothnessCost()
                        cost += calculateDataCost()
                        let node = MRF.nodes[y][x]
                        
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
            MRF.nodes[y][x - 1].messages[Direction.right.rawValue] = newMessage
        case .up:
            MRF.nodes[y - 1][x].messages[Direction.down.rawValue] = newMessage
        case .right:
            MRF.nodes[y][x + 1].messages[Direction.left.rawValue] = newMessage
        case .down:
            MRF.nodes[y + 1][x].messages[Direction.up.rawValue] = newMessage
        }
    }
    
    private func findBestLabelling() {
        // TODO: Find best label for pixel
    }
}
