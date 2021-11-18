import logging

import numpy as np


def make_initial_guesses(grays, edges):
    init_obstr = None
    init_back = None
    init_alpha = None
    obstr_motions = None
    back_motions = None

    logging.info("Calculating Edge Flows")
    edge_flows = []
    ref_frame_index = len(grays) // 2  # Middle frame = reference frame
    for idx in range(len(grays)):
        if idx != ref_frame_index:
            edge_flow = calculate_edge_flow(grays[idx], grays[ref_frame_index], edges[idx], edges[ref_frame_index])
            edge_flows.append(edge_flow)

    return init_obstr, init_back, init_alpha, obstr_motions, back_motions


def calculate_edge_flow(non_ref_image, ref_image, non_ref_edges, ref_edges):
    patch_radius = 2
    motion_radius = 15

    edge_pixel_coords = np.argwhere(non_ref_edges)
    motion_field = np.zeros((len(edge_pixel_coords), motion_radius * 2, motion_radius * 2))

    for idx in range(len(edge_pixel_coords)):
        motion_field[idx] = data_cost(non_ref_image, ref_image, edge_pixel_coords[idx], patch_radius, motion_radius)

    messages = np.zeros((len(edge_pixel_coords), 4, motion_radius * motion_radius * 4))  # point, direction, label

    for bp_iter in range(10):
        belief_propagation(messages, 0)
        belief_propagation(messages, 1)
        belief_propagation(messages, 2)
        belief_propagation(messages, 3)

    edge_flow = 1

    return edge_flow


def data_cost(non_ref_image, ref_image, pixel_coords, patch_size, motion_radius):
    # TODO - Implement normalized cross-correlation
    ncc = np.zeros((motion_radius * 2, motion_radius * 2))
    return ncc


def smoothness_cost():
    # TODO - Implement w12 stuff
    pass


def belief_propagation(messages, direction):
    # Direction: 0 - North, 1 - East, 2 - South, 3 - West
    pass


def send_message():
    # TODO - implement
    pass
