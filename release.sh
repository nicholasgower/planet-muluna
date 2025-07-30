#!/bin/bash

dir=$(dirname "$scriptpath")
cd "$dir" || exit


git archive --prefix=planet-muluna_1.99.6/ -o planet-muluna_1.99.6.zip HEAD
