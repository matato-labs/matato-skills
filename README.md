# Matato Pi Package

MatatoPi is a pi package with extensions, skills promps that could help to have a nice e2e workflow to write code AI using pi. It has an extra feature to scheudled work direactly linked to a skill and allows you to run deterministic scripts before the AI workflow trigger.

```bash
pi install /absolute/path/to/matato-pi
```
> You can install from github as well `pi -e git:github.com/user/repo`

## Features
* Subagents
* Scheduled jobs
* Plans and researches storage in local files
* E2E software lifecycle skills
* Prepare for AI assistant work

## Under development
* Telegram connection

## Development

### Test, Linting, Formating...
```bash
npm run test
npm run lint
npm run check
```

## Examples

### Plans
You can see all plans you have created with matato-pi with `/plans`, plans are stored in `~/.config/matato-pi/plans/{repo}/{name}.md`

### Researches
Researches are under `/researches` and they are stored in `~/.config/matato-pi/researches/{name}.md`


### Scheduled jobs
Scheduled jobs are configured via a json file under `~/.config/matato-pi/automations/config.json`, when you start the worker with `npm run worker`, it loads the configuration and created a cronjob for every entry. An automation is tight to an skill, they can only be executed if the skill exist, when it's tirggered, it will search for a script called `preScript.ts` under `{skillName}/scripts`, if it's present it's going to execute it and the outpt is going to be given to the skill as input.

To create/read/update/delete cron jobs, use `/automations`.