//
//  BeliefPropagation.metal
//  NoFencesPlease
//
//  Created by Shahmeer Athar on 2021-12-19.
//

#include <metal_stdlib>
using namespace metal;

kernel void beliefPropagationMessagePassingRound(texture2d<float, access::read> image [[texture(0)]],
                                                 texture2d<float, access::read> refImage [[texture(1)]],
                                                 texture2d<float, access::read> edgeMap [[texture(2)]],
                                                 device float* MRF [[buffer(0)]],
                                                 device float* newMRF [[buffer(1)]],
                                                 constant int& height [[buffer(2)]],
                                                 constant int& motionDiameter [[buffer(3)]],
                                                 constant int& direction [[buffer(4)]],
                                                 uint2 index [[thread_position_in_grid]])
{
    if (edgeMap.read(index)[0] == 0.0) {
        return;
    }
    
    // index[1] is the y coordinate
    // index[0] is the x coordinate
    int idx = (index[1] * height) + index[0];
    MRF[idx] += direction;
}
