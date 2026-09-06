#!/usr/bin/env bash
set -euo pipefail

list_projects() {
  matato --json project list
}

user=$(gh api user --jq .login)
projects=$(list_projects | bun -e 'const input=await Bun.stdin.text(); const normalize=(url:string)=>{const withoutGit=url.endsWith(".git")?url.slice(0,-4):url; const match=withoutGit.match(/github\.com[:\/]([^/]+\/[^/]+)$/); if(!match?.[1]) throw new Error(`Unsupported GitHub URL: ${url}`); return match[1]}; const lines=input.split(/\n/).map((line)=>line.trim()).filter(Boolean); const projects=lines.flatMap((line)=>{const urlMatch=line.match(/(?:https?:\/\/\S+|git@github\.com:\S+)$/); if(!urlMatch?.[0]) return []; const beforeUrl=line.slice(0,urlMatch.index).trim(); const firstSpace=beforeUrl.indexOf(" "); if(firstSpace === -1) return []; const name=beforeUrl.slice(firstSpace + 1).trim(); return [`${name}\t${urlMatch[0]}\t${normalize(urlMatch[0])}`]}); console.log(projects.join("\n"))')

if [ -z "$projects" ]; then
  echo '{"skip":true,"reason":"No configured projects with repository URLs"}'
  exit 0
fi

while IFS=$'\t' read -r project github_url repository; do
  if [ -z "$repository" ]; then
    continue
  fi

  number=$(gh issue list \
    -R "$repository" \
    --search "label:AI no:assignee state:open" \
    --limit 1 \
    --json number \
    --jq '.[0].number // empty')

  if [ -z "$number" ]; then
    continue
  fi

  gh issue edit "$number" -R "$repository" --add-assignee "$user" >/dev/null

  gh issue view "$number" \
    -R "$repository" \
    --json number,title,body,url,labels \
    --jq "{issue:{project:\"$project\",repositoryUrl:\"$github_url\",number:.number,title:.title,body:(.body // \"\"),url:.url,labels:[.labels[].name]},assignedTo:\"$user\"}"
  exit 0
done <<< "$projects"

echo '{"skip":true,"reason":"No available AI issues"}'
