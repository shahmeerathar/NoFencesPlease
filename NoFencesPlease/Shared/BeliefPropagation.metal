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
                              texture2d<float, access::write> output [[texture(2)]],
                              uint2 index [[thread_position_in_grid]])
{
    float4 color = float4(0.5, 0.5, 0.5, 1.0);
    output.write(color, index);
}
