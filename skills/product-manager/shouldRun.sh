#!/usr/bin/env bash
set -euo pipefail

if [ -z "${STORAGE_PATH:-}" ]; then
  echo 'STORAGE_PATH must be set' >&2
  exit 1
fi

timezone="${TIMEZONE:-UTC}"
output_directory='docs/productDevelopment'
state_file="$STORAGE_PATH/agent/product-manager.json"
local_date=$(TZ="$timezone" date +%F)
list_projects() {
  matato --json project list
}

project_line=$(list_projects | bun -e 'const input=await Bun.stdin.text(); const normalize=(url:string)=>{const withoutGit=url.endsWith(".git") ? url.slice(0,-4) : url; const match=withoutGit.match(/github\.com[:\/]([^/]+\/[^/]+)$/); if(!match?.[1]) throw new Error(`Unsupported GitHub URL: ${url}`); return match[1]}; const lines=input.split(/\n/).map((line)=>line.trim()).filter(Boolean); const project=lines.flatMap((line)=>{const urlMatch=line.match(/(?:https?:\/\/\S+|git@github\.com:\S+)$/); if(!urlMatch?.[0]) return []; const beforeUrl=line.slice(0,urlMatch.index).trim(); const firstSpace=beforeUrl.indexOf(" "); if(firstSpace === -1) return []; const name=beforeUrl.slice(firstSpace + 1).trim(); if(name !== "matato") return []; return [`${name}\t${urlMatch[0]}\t${normalize(urlMatch[0])}`]})[0] ?? ""; console.log(project)')

if [ -z "$project_line" ]; then
  echo '{"skip":true,"reason":"Matato project is not configured with a repository"}'
  exit 0
fi

IFS=$'\t' read -r project_name repository_url repository_name_with_owner <<< "$project_line"
mkdir -p "$(dirname "$state_file")"

if [ ! -f "$state_file" ]; then
  printf '{\n  "lastProposalDate": "",\n  "proposals": []\n}' > "$state_file"
fi

api_error=$(mktemp)
trap 'rm -f "$api_error"' EXIT
set +e
existing_proposal_file=$(gh api \
  "repos/$repository_name_with_owner/contents/$output_directory" \
  --jq ".[] | select(.type == \"file\" and (.name | startswith(\"$local_date-\"))) | .name" \
  2>"$api_error" | head -n 1)
api_status=${PIPESTATUS[0]}
set -e

if [ "$api_status" -ne 0 ] && ! grep -q 'Not Found' "$api_error"; then
  cat "$api_error" >&2
  exit "$api_status"
fi

if [ -n "$existing_proposal_file" ]; then
  LOCAL_DATE="$local_date" FILE="$output_directory/$existing_proposal_file" bun -e 'console.log(JSON.stringify({skip:true,reason:`Product proposal already exists for ${process.env.LOCAL_DATE}`,localDate:process.env.LOCAL_DATE,file:process.env.FILE}))'
  exit 0
fi

pull_requests=$(gh pr list \
  --repo "$repository_name_with_owner" \
  --state open \
  --search "product proposal $local_date in:title" \
  --json title,number,url \
  --jq "map(select(.title | startswith(\"product proposal $local_date\")))")

if [ "$pull_requests" != '[]' ]; then
  LOCAL_DATE="$local_date" PULL_REQUESTS_JSON="$pull_requests" bun -e 'console.log(JSON.stringify({skip:true,reason:`Open product proposal pull request already exists for ${process.env.LOCAL_DATE}`,localDate:process.env.LOCAL_DATE,pullRequests:JSON.parse(process.env.PULL_REQUESTS_JSON ?? "[]")}))'
  exit 0
fi

state_summary=$(STATE_FILE="$state_file" bun -e 'const state=await Bun.file(process.env.STATE_FILE ?? "").json(); console.log(`${state.lastProposalDate ?? ""}|${state.proposals?.length ?? 0}`)')
IFS='|' read -r last_proposal_date proposals_count <<< "$state_summary"

if [ "$last_proposal_date" = "$local_date" ]; then
  LOCAL_DATE="$local_date" bun -e 'console.log(JSON.stringify({skip:true,reason:`Product proposal already created for ${process.env.LOCAL_DATE}`,localDate:process.env.LOCAL_DATE}))'
  exit 0
fi

LOCAL_DATE="$local_date" \
TIMEZONE_VALUE="$timezone" \
STATE_FILE="$state_file" \
OUTPUT_DIRECTORY="$output_directory" \
PROJECT="$project_name" \
REPOSITORY_URL="$repository_url" \
LAST_PROPOSAL_DATE="$last_proposal_date" \
PROPOSALS_COUNT="$proposals_count" \
bun -e 'console.log(JSON.stringify({localDate:process.env.LOCAL_DATE,timezone:process.env.TIMEZONE_VALUE,stateFile:process.env.STATE_FILE,outputDirectory:process.env.OUTPUT_DIRECTORY,project:process.env.PROJECT,repositoryUrl:process.env.REPOSITORY_URL,lastProposalDate:process.env.LAST_PROPOSAL_DATE,proposalsCount:Number(process.env.PROPOSALS_COUNT ?? 0)}))'
