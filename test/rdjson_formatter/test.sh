#!/bin/bash
# Expected to run from the root repository.
set -eux
CWD=$(pwd)
bundler-audit check ./test/rdjson_formatter/testdata/ --format json \
  | ruby ./rdjson_formatter/rdjson_formatter.rb test/rdjson_formatter/testdata/Gemfile.lock \
  | jq . \
  | sed -e "s!${CWD}/!!g" \
  > ./test/rdjson_formatter/testdata/result.out
diff -u ./test/rdjson_formatter/testdata/result.*
