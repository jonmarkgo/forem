#!/bin/bash
export PATH="/home/exedev/.rubies/ruby-3.3.0/bin:$PATH"
eval "$(rbenv init -)"
bundle exec "$@"
