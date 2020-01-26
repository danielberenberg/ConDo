# ConDo
Contact based protein Domain boundary prediction method

- [Dependencies](#dependencies)
- [Installation](#installation)
- [References](#references)


# Dependencies
## Bioinformatics software
- [BLAST](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download)
  - Any version with `blastpgp` will probably work. We use `2.2.26`.
  - Direct FTP: `ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/`

- [HHblitz](https://github.com/soedinglab/hh-suite.git)
- [PSIPRED](http://bioinfadmin.cs.ucl.ac.uk/downloads/psipred)
- [SANN](https://github.com/newtonjoo/sann)
## Other packages
- Python 3 (v3.6.5+)
- Tensorflow (tested on v1.14)
- `gcc`
##  Databases
- [UniRef90](https://www.uniprot.org/downloads)
  - For BLAST.
- [UniClust30](http://gwdu111.gwdg.de/~compbiol/uniclust/2018_08/)
  - For HHSearch.

# Installation
To be described
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

