#!/bin/bash

dir=$(dirname "$scriptpath")
cd "$dir" || exit


git archive --prefix=planet-muluna_1.45.12/ -o planet-muluna_1.45.12.zip HEAD
