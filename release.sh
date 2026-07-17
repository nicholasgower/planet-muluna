#!/bin/bash

dir=$(dirname "$scriptpath")
cd "$dir" || exit


git archive --prefix=planet-muluna_2.2.100/ -o planet-muluna_2.2.100.zip HEAD
