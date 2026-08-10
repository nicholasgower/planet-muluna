#!/bin/bash

dir=$(dirname "$scriptpath")
cd "$dir" || exit


git archive --prefix=planet-muluna_2.2.106/ -o planet-muluna_2.2.106.zip HEAD
