#!/bin/bash

dir=$(dirname "$scriptpath")
cd "$dir" || exit


git archive --prefix=planet-muluna_2.0.0/ -o planet-muluna_2.0.0.zip HEAD
