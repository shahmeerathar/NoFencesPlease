import os
import logging

import numpy as np
import cv2 as cv

from initialize import make_initial_guesses


def view_img_array(arr):
    for img in arr:
        cv.imshow("Image", img)
        cv.waitKey(0)


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)

    input_path = "Sequence/"
    file_names = os.listdir(input_path)
    file_names.sort()

    images = []
    grays = []
    edges = []
    try:
        file_names.remove(".DS_Store")
    except ValueError:
        print("No DS_Store")

    # Load images and get edge maps
    logging.info("Loading images and obtaining edge maps")

    for image in file_names:
        path = os.path.join(input_path, image)
        print(path)
        img = cv.imread(path)
        images.append(img)

        gray = cv.cvtColor(img, cv.COLOR_BGR2GRAY)
        grays.append(gray)

        # Seems to be the standard
        edge = cv.Canny(img, int(max(0, 0.67 * np.median(img))), int(max(255, 1.33 * np.median(img))))
        # Seems to give better results
        edge = cv.Canny(img, 100, 100)
        edges.append(edge)

    init_obstr, init_back, init_alpha, obstr_motions, back_motions = make_initial_guesses(grays, edges)
