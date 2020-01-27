# ConDo
Contact based protein Domain boundary prediction method

- [Dependencies](#dependencies)
  - [Bioinformatics software](#bioinf)
  - [Databases](#data)
  - [Other software](#other)
- [Installation](#installation)
- [References](#references)

# Dependencies
<a name="bioinf"></a>
## Bioinformatics software
- [BLAST](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download)
  - Any version with `blastpgp` will probably work (we use `2.2.26`).
  - Direct FTP: `ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/`
- [HHblitz](https://github.com/soedinglab/hh-suite.git)
- [PSIPRED](http://bioinfadmin.cs.ucl.ac.uk/downloads/psipred)
<a name="data"></a>
- [SANN](https://github.com/newtonjoo/sann)
##  Databases
- [UniRef90](https://www.uniprot.org/downloads)
  - For BLAST (we use the most current version).
- [UniClust30](http://gwdu111.gwdg.de/~compbiol/uniclust/2018_08/)
  - For HHSearch (we use `2018_08`).
<a name="other"></a>
## Other packages
- Python 3 (v3.6.5+)
- Tensorflow (tested on v1.14)
- `gcc`

# Installation
- Installing dependencies
  - _SANN_: Some in-house changes have been made. Inquire within for a working installation.
  - _BLAST_, _PSIPRED_, and _HHblitz_: Follow installation instructions
- Installing ConDo
  - Adjust paths `ConDo.PATH` to suite your environment.
  - Adjust paths in `scripts/setup.bash` to suit your environment.
    - The purpose of `scripts/setup.bash` is to copy the the UniClust directory to shared memory in order to allow
      multiple processes to read from it in parallel quicker. This step may not suit your needs. To that end,
      some slight finessing might be required in which you change `$DB_SHM_PATH` in `scripts/ConDo.sh` to `${UNICLUST_DKS_PATH}`.

  - Inside of main ConDo directory, compile: `gcc src/feature.c -o bin/feature -lm -fopenmp -g`
    - The `-g` sets debug symbols. Change `-g` to `-O2` for 2nd or performance optimization.

# Notes
- Absolute filepaths must be less than 1000 characters (due to memory allocation in embedded programs).

# References
Hong, Seung Hwan, Keehyoung Joo, and Jooyoung Lee. "ConDo: Protein domain boundary prediction using coevolutionary information." Bioinformatics (2018).

```bibtex
@article{10.1093/bioinformatics/bty973,
    author = {Hong, Seung Hwan and Joo, Keehyoung and Lee, Jooyoung},
    title = "{ConDo: protein domain boundary prediction using coevolutionary information}",
    journal = {Bioinformatics},
    volume = {35},
    number = {14},
    pages = {2411-2417},
    year = {2018},
    month = {11},
    issn = {1367-4803},
    doi = {10.1093/bioinformatics/bty973},
    url = {https://doi.org/10.1093/bioinformatics/bty973},
    eprint = {https://academic.oup.com/bioinformatics/article-pdf/35/14/2411/28913279/bty973.pdf},
}
```

