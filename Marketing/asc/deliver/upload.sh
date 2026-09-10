#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

: "${ASC_KEY_ID:?Set ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID}"
: "${ASC_KEY_PATH:?Set ASC_KEY_PATH to AuthKey_XXX.p8}"

if ! command -v fastlane >/dev/null 2>&1; then
  echo "Installing fastlane via gem user install..."
  gem install fastlane --user-install
  export PATH="$HOME/.gem/ruby/$(ruby -e 'print RbConfig::CONFIG["ruby_version"]')/bin:$PATH"
fi

export APP_STORE_CONNECT_API_KEY_KEY_ID="$ASC_KEY_ID"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="$ASC_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_KEY_FILEPATH="$ASC_KEY_PATH"
export FASTLANE_DISABLE_COLORS=1

fastlane deliver \
  --app_identifier "com.mamba.snake" \
  --api_key_path <(python3 - <<PY
import json, os
print(json.dumps({
  "key_id": os.environ["ASC_KEY_ID"],
  "issuer_id": os.environ["ASC_ISSUER_ID"],
  "key": open(os.environ["ASC_KEY_PATH"]).read(),
  "in_house": False
}))
PY
) \
  --skip_binary_upload true \
  --skip_metadata false \
  --skip_screenshots false \
  --overwrite_screenshots true \
  --force true \
  --submit_for_review false \
  --precheck_include_in_app_purchases false \
  --metadata_path ./metadata \
  --screenshots_path ./screenshots
