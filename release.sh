#!/bin/bash

dir=$(dirname "$scriptpath")
cd "$dir" || exit


git archive --prefix=planet-muluna_1.99.8/ -o planet-muluna_1.99.8.zip HEAD
