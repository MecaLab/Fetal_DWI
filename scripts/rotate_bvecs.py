#!/usr/bin/env python

import argparse
import re
import numpy as np
from nibabel.tmpdirs import InTemporaryDirectory
import subprocess


def parse_fsl_affine(file):
    with open(file) as f:
        lines = f.readlines()
    entries = [l.split() for l in lines]
    entries = [row for row in entries if len(row) > 0]  # remove empty rows
    return np.array(entries).astype(np.float32)


def read_bvecs(this_fname):
    """
    Adapted from dipy.io.read_bvals_bvecs
    """
    with open(this_fname, 'r') as f:
        content = f.read()
    # We replace coma and tab delimiter by space
    with InTemporaryDirectory():
        tmp_fname = "tmp_bvals_bvecs.txt"
        with open(tmp_fname, 'w') as f:
            f.write(re.sub(r'(\t|,)', ' ', content))
        return np.squeeze(np.loadtxt(tmp_fname)).T
    

def get_rotation_matrix(matrix_file):

    # Run fsl avscale and capture the output
    result = subprocess.run(['avscale', '--allparams', matrix_file], capture_output=True, text=True, check=True)
    output = result.stdout
    
    # Regex pattern to extract the rotation matrix
    matrix_pattern = re.search(r"Rotation & Translation Matrix:\n([\-\d\.\s]+)\n([\-\d\.\s]+)\n([\-\d\.\s]+)\n([\-\d\.\s]+)\n", output)
    
    matrix_lines = matrix_pattern.groups()[:3]  # Extract only the first, second, and third rows (rotation part)
    matrix = np.array([list(map(float, line.split()[:3])) for line in matrix_lines])
    
    return matrix


def main():
    parser = argparse.ArgumentParser(description="Apply FSL linear transformation to bvecs.",
                                     epilog="Written by Jakob Wasserthal.")
    parser.add_argument("-i", metavar="bvecs_in", dest="bvecs_in",
                        help="bvecs input file", required=True)
    parser.add_argument("-t", metavar="affine_in", dest="affine_in",
                        help="affine transformation (FSL .mat file)", required=True)
    parser.add_argument("-o", metavar="bvecs_out", dest="bvecs_out",
                        help="bvecs output file", required=True)
    args = parser.parse_args()

    bvecs = read_bvecs(args.bvecs_in)
    rotation = get_rotation_matrix(args.affine_in)

    # Apply rotation to bvecs
    bvecs = np.array(bvecs).T  # change shape from [nr_vecs, 3] to [3, nr_vecs]
    rotated_bvecs = np.matmul(rotation, bvecs)  # output shape [3, nr_vecs]
    np.savetxt(args.bvecs_out, rotated_bvecs, fmt='%1.6f')


if __name__ == '__main__':
    main()
