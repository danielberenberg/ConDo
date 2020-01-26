"""
Python implementation of feature.c
"""

import sys
import numpy as np


# Globals
SEQ_CODE = "-ARNDCQEGHILKMFPSTWYVX"
N_TYPE   = len(SEQ_CODE)


def read_seq(target):
    raise NotImplementedError


def mod_seq(sequence):
    raise NotImplementedError


def read_ss2(target):
    raise NotImplementedError

def read_sa2(target):
    raise NotImplementedError

def read_msa(target):
    raise NotImplementedError

def find_nmsa(target):
    raise NotImplementedError

def read_profile(target):
    raise NotImplementedError

def get_n_signal(target):
    raise NotImplementedError



if __name__ == '__main__':
    target = sys.argv[1]

