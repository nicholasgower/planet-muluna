#!/bin/bash

dir=$(dirname "$scriptpath")
cd "$dir" || exit


git archive --prefix=planet-muluna_1.99.7/ -o planet-muluna_1.99.7.zip HEAD
