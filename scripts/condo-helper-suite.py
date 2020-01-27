#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Compile features into Python readable format, make predictions, and interpret results. 
"""

import sys, os 
import warnings
import logging
import argparse
import textwrap
import itertools
from pathlib import Path

import numpy as np


DEFAULT_WEIGHT_FILE = os.environ.get("WEIGHT_FILE")

def _window(seq, n=2):
    """Returns a sliding window (of width n) over data from the iterable
    s -> (s0, s1, ..., s[n-1]), (s1, s2 ... sn), ...
    """
    it = iter(seq)
    result = tuple(itertools.islice(it, n))
    if len(result) == n:
        yield result
    for elt in it:
        resut = result[1:] + (elem, )
        yield result

def _locate_by_extension(session, suffix):
    """
    args:
        :session (Path or str) - the ConDo session to check
        :suffix (str) - Extension with (ext and .ext are both valid.)
    yields:
        :session/*.suffix
    """
    session = Path(session)
    suffix  = suffix.lstrip('.')
    glob = session.glob(f"*.{suffix}")

    yield from glob

def _create_model(weights):
    """Ported from the original prediction.py script"""
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'  # or any {'0', '1', '2'}
        import tensorflow as tf
        tflogging = tf.compat.v1.logging
        tflogging.set_verbosity(tflogging.ERROR)

        models = tf.keras.models
        layers = tf.keras.layers

        model = models.Sequential()

        model.add(layers.Dense(units=1500, input_dim=1129))
        model.add(layers.Activation("relu"))
        model.add(layers.Dropout(0.5))

        for i in range(0,3):
            model.add(layers.Dense(units=1500, input_dim=1500))
            model.add(layers.Activation("relu"))
        model.add(layers.Dropout(0.5))

        model.add(layers.Dense(units=4, input_dim=1500))
        model.add(layers.Activation("sigmoid"))

        model.compile(loss='binary_crossentropy',
                  optimizer='adadelta',
                  metrics=['accuracy'])
        model.load_weights(weights)
    return model

def _read_sequence(fastafile):
    with open(fastafile, 'r') as fasta:
        for is_header, group in itertools.groupby(fasta, lambda line: line.startswith(">")):
            if is_header:
                pass
            else:
                return "".join(line.strip() for line in group)
    
def gather(args):
    """Prepares neural network input into NumPy readable format.
    args:
        :session (Path) - ConDo session directory.
    returns:
        :(bool) - whether there was any work to actually be done.
        :by side effect saves feature files
    """
    ran = False
    for feature_file in _locate_by_extension(args.session, '.feature.txt'):
        outfile = feature_file.with_suffix('').with_suffix(".feature.npz")
        if outfile.exists() and args.dont_overwrite: continue
        with open(feature_file, 'r') as featuretxt:
            features = list(map(lambda line: np.array(line.split()[1:], dtype=np.float32), featuretxt))
            if args.verbose:
                print(f"[gather] Saving the contents of {feature_file} to {outfile}.")
            np.savez(outfile, feature=features)
        ran = True
    return ran


def predict(args):
    """Makes prediction(s).
    args:
        :args - the command line arguments.
    returns:
        :(bool) - whether the routine ran
        :by side effect makes predictions and writes them to an npz feature file.
    """
    
    model = _create_model(str(args.weights))
    ran   = False
    for feature_file in _locate_by_extension(args.session, '.feature.npz'):
        predfile = feature_file.with_suffix('').with_suffix(".prediction.npz")
        if predfile.exists() and args.dont_overwrite: continue
        try:
            pred = model.predict(np.load(feature_file)['feature']) 
            np.savez(predfile, predictions=pred)
            if args.verbose:
                print(f"[predict] Saving predictions from {feature_file} to {predfile}.")
        except KeyError:
            warnings.warn("[predict] Malformed feature file! Skipping.", UserWarning, stacklevel=1)
            continue 
        ran = True
    return ran


def generate_result(args):
    """Interpret results.

    args:
        :args - the commandline arguments
    returns:
        :(bool) - whether there was any work to actually be done.
        :by side effect writes a TSV file
    """

    ran = False
    fw = 40
    for predfile in _locate_by_extension(args.session, '.prediction.npz'):
        resultfile  = predfile.with_suffix().with_suffix(".ConDo.tsv")
        domainfile  = predfile.with_suffix().with_suffix(".domains.tsv")
        displayfile = predfile.with_suffix().with_suffix(".ConDo.txt")

        if resultfile.exists() and args.dont_overwrite: continue

        try:
            pred_boundary = np.load(predfile)['predictions']  # this should definitely exist, it is the output of a glob.
            fasta = (predfile.parent / predfile.stem).with_suffix('.fasta')
            sequence = _read_sequence(fasta)
            N = len(sequence)
        except KeyError:
            warnings.warn("[generate-result] Malformed prediction file! Skipping.", UserWarning, stacklevel=1)
            continue
        except FileNotFoundError:
            warnings.warn(f"[generate-result] Cannot find {predfile.with_suffix('.fasta')}. Skipping.", UserWarning, stacklevel=1)
            continue
        
        # each element of pred_boundary is a 4 tuple, the sum of which yields the score
        scores = np.array(list(map(sum, pred_boundary)))
        #scores     = np.array(scores)
        arg_scores = np.argsort(-scores)

        # determine boundaries
        above_thresh = lambda x: x > args.cutoff
        valid_bnd = lambda bndidx, score: above_thresh(score) and fw < bndidx < N - fw -1

        lbounds, rbounds, lbound_scores = [], [], []
        # pull all residues above domain boundary cutoff 
        for i, score in itertools.takewhile(lambda tup: above_thresh(tup[0]), map(lambda i: (i, scores[i]),
                                                                         arg_scores)):
            if i < 1 or i > N - 2: continue
            # inside of a predefined domain
            if not any(abs(bound - (i + 1)) < fw for bound in lbounds):
                # shift left if appropriate
                lb = i if scores[i + 1] < scores[i - 1] else i + 1
                rb = lb + 1
                lbounds.append(lb)
                rbounds.append(rb)

                lbound_scores.append(scores[lb])
        
        # ====================== display ====================== #
        multidomain = False
        bounds = []
        
        old = 0
        domains = []
        for lb, rb, sc in zip(lbounds, rbounds, lbound_scores):
            valid = valid_bnd(lb, sc)
            multidomain |= valid
            if valid: 
                bounds = itertools.chain([lb, sc], bounds)
                domains.append((old, lb))
                old = rb
    
        domains.append((old, N))
        displays = [displayfile, sys.stdout] if args.verbose else [displayfile]

        print_files("================== ConDo Results ==================", files=displays)
        print_files(f"Session: {args.session}", files=displays)
        print_files(f"Sequence:\n{textwrap.fill(sequence, 60)}", files=displays)
        print_files(f"Length: {N}", files=displays)
        print_files("==================   Domains  =====================", files=displays)

        with open(domainfile, 'w') as domainhandle:
            print("domain_number", "start", "end", file=domainhandle, sep='\t')
            for i, domain in enumerate(domains,1):
                print_files(f"{i}) {domain}", files=displays)
                print(i, *domain, sep='\t' file=domainhandle)

        print_files(f"\tSample is multidomain: {multidomain}", files=displays)
        bounds = list(bounds) 
        with open(resultfile, 'w') as results:
            print("position", "amino", "score", "on_domain_boundary", file=results, sep='\t')
            for idx, (amino, score) in enumerate(zip(sequence, scores), 1):
                print(idx, amino, score, int(idx in bounds), file=results, sep='\t')
        ran = True
    return ran

def print_files(*args, files=None, modes='a', **kwargs):
    kwargs['file'] = None
    assert isinstance(modes, (str, list))

    if isinstance(modes, list):
        assert len(modes) == len(files)
    else:
        modes = itertools.repeat(modes)
    del kwargs['file']
    for filename in (files or []):
        if isinstance(filename, (str, Path)):
            f = open(filename, mode)
        print(*args, file=f, **kwargs) 



routines = [gather, predict, generate_result]

def curry(args):
    """Curries the script, excecuting the next step in the pipeline.
    """ 

    # Just iterate through the reversed set of routines until one 'runs'.
    for routine in reversed(routines):
        if routine(args): sys.exit(0)
    if args.verbose:
        print("[curry] Nothing to be done!")

def run(args):
    """Runs the script entirely, executing every step."""
    for routine in routines:

        routine(args)

subcommands = {gather: "Gather features into Python readable format.", 
               predict: "Make predictions.",
               generate_result: "Interpret results.", 
               curry: "Perform the next step in the gather, predict, result pipeline.",
               run: "Run the entire pipeline."}


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)

    subparsers_factory = parser.add_subparsers()
    subparsers = dict()
    for subcommand, helpmsg in subcommands.items():
        name = subcommand.__name__.replace('_', '-')
        subparser = subparsers_factory.add_parser(name, help=helpmsg)
        subparser.set_defaults(func=subcommand)
        subparsers[name] = subparser

        subparser.add_argument("session", type=Path, help="ConDo session directory.")

    
    for subkey in ['predict', 'curry', 'run']:
        subparsers[subkey].add_argument("-w", "--weight-file", type=Path, dest='weights',
                                        help=f"Predictor weights. (default = {DEFAULT_WEIGHT_FILE or 'No default found!'})",
                                        default=DEFAULT_WEIGHT_FILE, required=DEFAULT_WEIGHT_FILE is None)

    for subkey in ['generate-result', 'curry', 'run']:
        subparsers[subkey].add_argument('-c', '--conf-cut', dest='cutoff', type=float, default=1.4,
                                        help=f"Confidence cutoff. (default = 1.4)")

    parser.add_argument("-v", "--verbose", dest="verbose",
                        help="Verbose output.", action='store_true', default=False)
    parser.add_argument("--no-overwrite", dest="dont_overwrite",
                        default=False, action='store_true',
                        help="Don't overwrite files. (default = False)")
    return parser.parse_args()

if __name__ == '__main__':
    args = arguments()
    args.func(args)
