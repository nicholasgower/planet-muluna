#!/bin/bash

dir=$(dirname "$scriptpath")
cd "$dir" || exit


git archive --prefix=planet-muluna_1.99.1/ -o planet-muluna_1.99.1.zip HEAD
