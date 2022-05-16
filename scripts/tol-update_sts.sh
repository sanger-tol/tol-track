#!/usr/bin/env bash
#
#    Copyright (C) 2021 Genome Research Ltd.
#
#    Author: Shane McCarthy <sm15@sanger.ac.uk>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.


# Run the ToLQC SQL query on the STS database
# Remove trailing whitespace in columns
/usr/bin/psql ${STSDB} -A -F $'\t' \
-f ${TOLQCROOT}/track/tol_sts.sql | \
awk 'NF>2' | sed -r "s/ +\t/\t/g; s/‘/'/g; s/’/'/g" > ${TOLQCROOT}/track/tol_sts.tsv.part

if [[ -s ${TOLQCROOT}/track/tol_sts.tsv.part ]];
then
    mv ${TOLQCROOT}/track/tol_sts.tsv.part ${TOLQCROOT}/track/tol_sts.tsv
fi
