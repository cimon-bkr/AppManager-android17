#!/data/data/com.termux/files/usr/bin/sh
# Pushes recent App Manager logcat output to the "logs" branch of your repo so Claude can read it.
# Setup (Termux): pkg install android-tools curl; pair + connect adb to localhost (Wireless debugging).
# Then:  export GH_TOKEN=<fine-grained token: ONLY this repo, Contents = read/write>
#        sh send-log.sh            # last 1500 lines, AppManager + crashes
#        sh send-log.sh 4000       # custom line count
REPO="cimon-bkr/AppManager-android17"
BRANCH="logs"
LINES="${1:-1500}"
: "${GH_TOKEN:?set GH_TOKEN first}"

TS=$(date -u +%Y%m%d-%H%M%S)
OUT="/data/local/tmp/am-$TS.log"
TMP="$HOME/am-$TS.log"

{
  echo "== device =="; adb shell getprop ro.product.model; adb shell getprop ro.build.version.release
  adb shell getprop ro.build.version.sdk; adb shell getprop ro.build.display.id
  echo "== logcat (last $LINES lines, filtered) =="
  adb logcat -d -v threadtime -t 20000 2>/dev/null \
    | grep -i -E "muntashirakon|AppManager|AndroidRuntime|FATAL|ActivityManager.*(am_crash|Process .* has died)|DEBUG|libc.*Fatal|avc: +denied.*(muntashirakon|appmanager)" \
    | tail -n "$LINES"
} > "$TMP"

API="https://api.github.com/repos/$REPO"
H1="Authorization: Bearer $GH_TOKEN"
H2="Accept: application/vnd.github+json"

# create the logs branch from main if it does not exist yet
if ! curl -sf -H "$H1" -H "$H2" "$API/git/ref/heads/$BRANCH" >/dev/null; then
  SHA=$(curl -s -H "$H1" -H "$H2" "$API/git/ref/heads/main" | grep -m1 '"sha"' | cut -d'"' -f4)
  curl -s -X POST -H "$H1" -H "$H2" "$API/git/refs" -d "{\"ref\":\"refs/heads/$BRANCH\",\"sha\":\"$SHA\"}" >/dev/null
fi

B64=$(base64 -w0 "$TMP")
RES=$(curl -s -o /dev/null -w "%{http_code}" -X PUT -H "$H1" -H "$H2" \
  "$API/contents/logs/am-$TS.log" \
  -d "{\"message\":\"log $TS\",\"branch\":\"$BRANCH\",\"content\":\"$B64\"}")
echo "upload: HTTP $RES  (logs/am-$TS.log on branch $BRANCH)  — 201 means success; tell Claude it's sent."
