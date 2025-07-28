#!/bin/bash

dir=$(dirname "$scriptpath")
cd "$dir" || exit


git archive --prefix=planet-muluna_1.99.4/ -o planet-muluna_1.99.4.zip HEAD
