# Tree of Life tracking

* `scripts/` contains scripts (`tol-update*`) used for tracking sequencing data in Sanger iRODS systems for Tree of Life projects. Most data tracked in simple TSV files as temporary solution until the database becomes functional. Also, a resurrected script (`tol-register-ena-bioprojects`) for registering ENA BioProjects and a script (`smrt-report`) for downloading and generating the PacBio QC plots shown in SMRTlink for `subreads.bam` files.

* `modules/` contains initial work for a database (`ATrack`) based on the old [VRTrack](https://github.com/VertebrateResequencing/vr-codebase/tree/develop/modules/VRTrack) database to store tracking data. Probably abandoned in favour of STS.
