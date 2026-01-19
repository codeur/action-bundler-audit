#!/usr/bin/env bash

set -e
set -o pipefail

cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit
export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"

echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
curl -sfL "https://raw.githubusercontent.com/reviewdog/reviewdog/${REVIEWDOG_VERSION}/install.sh" | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
echo '::endgroup::'

if [ "${INPUT_SKIP_INSTALL}" = "false" ]; then
  echo '::group:: Installing bundler-audit ... https://github.com/rubysec/bundler-audit'
  # if 'gemfile' bundler-audit version selected
  if [ "${INPUT_BUNDLER_AUDIT_VERSION}" = "gemfile" ]; then
    # if Gemfile.lock is here
    if [ -f 'Gemfile.lock' ]; then
      # grep for bundler-audit version
      BUNDLER_AUDIT_GEMFILE_VERSION=$(ruby -ne 'print $& if /^\s{4}bundler-audit\s\(\K.*(?=\))/' Gemfile.lock)

      # if bundler-audit version found, then pass it to the gem install
      # left it empty otherwise, so no version will be passed
      if [ -n "$BUNDLER_AUDIT_GEMFILE_VERSION" ]; then
        BUNDLER_AUDIT_VERSION=$BUNDLER_AUDIT_GEMFILE_VERSION
      else
        printf "Cannot get the bundler-audit's version from Gemfile.lock. The latest version will be installed."
      fi
    else
      printf 'Gemfile.lock not found. The latest version will be installed.'
    fi
  else
    # set desired bundler-audit version
    BUNDLER_AUDIT_VERSION=$INPUT_BUNDLER_AUDIT_VERSION
  fi

  gem install -N bundler-audit --version "${BUNDLER_AUDIT_VERSION}"
  echo '::endgroup::'
fi

if [ "${INPUT_USE_BUNDLER}" = "false" ]; then
  BUNDLE_EXEC=""
else
  BUNDLE_EXEC="bundle exec "
fi

echo '::group:: Running bundler-audit with reviewdog 🐶 ...'
# shellcheck disable=SC2086
${BUNDLE_EXEC}bundler-audit update

# shellcheck disable=SC2086
${BUNDLE_EXEC}bundler-audit check ${INPUT_BUNDLER_AUDIT_FLAGS} --format json --quiet \
  | ruby ${GITHUB_ACTION_PATH}/rdjson_formatter/rdjson_formatter.rb \
  | reviewdog -f=rdjson \
      -name="${INPUT_TOOL_NAME}" \
      -reporter="${INPUT_REPORTER}" \
      -filter-mode="${INPUT_FILTER_MODE}" \
      -fail-level="${INPUT_FAIL_LEVEL}" \
      -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
      -level="${INPUT_LEVEL}" \
      ${INPUT_REVIEWDOG_FLAGS}

reviewdog_rc=$?
echo '::endgroup::'
exit $reviewdog_rc
