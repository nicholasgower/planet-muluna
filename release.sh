#!/bin/bash

dir=$(dirname "$scriptpath")
cd "$dir" || exit


git archive --prefix=planet-muluna_1.99.5/ -o planet-muluna_1.99.5.zip HEAD
