#!/bin/bash

dir=$(dirname "$scriptpath")
cd "$dir" || exit


git archive --prefix=planet-muluna_1.99.10/ -o planet-muluna_1.99.10.zip HEAD
