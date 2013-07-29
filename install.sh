#!/usr/bin/env bash

rm *.gem && gem build engineyard-serverside.gemspec && sudo gem install *.gem
