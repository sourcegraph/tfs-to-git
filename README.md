# TFS to Git Conversion Tool

TFVC repo goes in, Git repo comes out

Forked from https://github.com/turbo/gtfotfs, then substantially refactored

Runs on Bash v4, so it doesn't require Windows like git-tfs

Doesn't run on Apple Silicon Macs until https://github.com/microsoft/team-explorer-everywhere/issues/334 is resolved

Developed and tested on Ubuntu, YMMV

## How to Migrate TFVC Repos to Git

### Step 1: Install and configure prerequisites

1. Java
  - Required by `tf`
  - `apt install default-jre`
2. `tf`
  - Team Explorer Everywhere, Microsoft's Java CLI for TFS
  - Requires Java
  - This script makes use of `tf`'s saved credentials feature; be sure to use an access token with least privileges
  - Initial setup:
    - Download latest from https://github.com/Microsoft/team-explorer-everywhere/releases
    - Either provide username and access token when running the script for the first time on each machine, or login manually before running the script:
```bash
export TF_AUTO_SAVE_CREDENTIALS=1
tf eula -accept
# Run any tf command, and supply account credentials using the `-login` option
tf workspaces -collection:https://dev.azure.com/YourCollectionName/ -login:user@domain.com,accesstoken
```
3. `jq`
  - Standard JSON query tool
  - Install via your package manager, ex. `apt install jq`
4. `xml2json`
  - Install via `pip install https://github.com/hay/xml2json/zipball/master`
5. `git`

Ensure these prerequisites are under directories in your $PATH
```bash
echo "export PATH=/installeddirectory/:$PATH" >> ~/.bashrc
source ~/.bashrc
```

### Step 2: Choose what to migrate

- Source TFVC repository path
  - This script is currently written to only convert a single source path into a single git repo
  - The default is `$/`, which includes all projects in your TFS org (collection)
  - Given that TFVC doesn't have a repo size limit, or any way to show you how large the repo is, and git has substantial issues with large repo sizes, you'll want to choose a path from your TFVC repo that makes more sense, and provide it in the format `$/project/app/main/dev/branch`
  - You can run `tfs-to-git.sh --repo-size -c COLLECTION -s SOURCE_PATH`, which will `tf get -force` the latest changeset in that collection and path, and run a `du -sch *` in the local workspace. This command does not clean up the files, so if you need to convert repo history after running this command, you'll want to run this script again with the `-fr` arg to force replace the local repo.
- History
  - Pick the oldest changeset ID you want migration to start with to retain history, and provide it with the `--history` arg
  - The default behaviour is to convert all changesets, retaining all history
- `.gitignore`
  - You can create a `.gitignore` file, and pass its file path in with the `--git-ignore-file` arg
  - It will be committed to the destination git repo, so the git CLI will apply it to all commits, dropping the matching files from the TFVC repository
  - This is a good way to exclude binary or media files from the git repo

### Step 3: [Optional] Create a new remote repo

- If you want this script to push the git repo to a remote, provide the full repo URL in the `--remote` arg
- Set up an empty git repository somewhere and copy the remote origin path
- This script assumes the the git CLI already has authentication and push access to this remote in place
- If not, the final stage to push the repo to this remote will fail, the local copy of the git repo is retained

### Step 4: Map TFS changeset owner names to Git author names

- TFS repo metadata stores authors in the format of your authentication scheme
  - ex. `user@domain.com` or `domain\username`
- These need to be mapped to proper git author tags
  - ex. `First Last <first.last@domain.com>`
- Ex. `./authors.json` file contents
```json
{
    "first.last@domain.com": "First Last <first.last@domain.com>",
    ...
}
```

### Step 5: Run

Run the script without arguments to view the current / full usage instructions

## Notes

1. This can take quite a while. In a test run, a migration of 3500 changesets with 800 MB of content took 10 hours to complete.

2. Original changeset dates will be preserved, and set as both git author and commit dates.

3. To get the number of changesets in the history of a file path, run the script at that source path, with a large number (up to 64 bit signed integer) for the `--batch-size` argument, wait for it to pull the history file, and output `Changesets received in this batch: x`. ex:
```bash
./tfs-to-git.sh \
  --force-replace \
  -c COLLECTION \
  -s $/project/source/path \
  --batch-size 9223372036854775807
```
