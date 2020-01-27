import sys

def parse_sequence_from_fasta(fastafile):
    """Retrieve the sequence from a single sequence fasta file."""
    with open(fastafile, 'r') as fp:
        header   = next(fp).strip()
        sequence = ''.join(line.strip() for line in fp)
    return header, sequence

if __name__ == "__main__":
    fasta = sys.argv[1]
    header, sequence = parse_sequence_from_fasta(fasta)
    if ">" in sequence:
        print("[standardize-fasta] Multi-entry FASTA. Quitting.")
        sys.exit(1)
    else:
        with open(fasta, 'w') as f:
            print(header, file=f)
            print(sequence, file=f)
            print(file=f)
        sys.exit(0)
