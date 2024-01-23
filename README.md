# TFS to Git Conversion Tool

TFVC repo goes in, Git repo comes out

Forked from https://github.com/turbo/gtfotfs then substantially refactored

Made for unattended migration using a unix system, i.e. doesn't require Windows like git-tfs

Doesn't run on Apple Silicon Macs until https://github.com/microsoft/team-explorer-everywhere/issues/334 is resolved

Developed and tested on Ubuntu, YMMV

## Migration Guide

### Step 1: Install and configure prerequisites

1. Java
  - Required by `tf`
  - `apt install default-jre`
2. `tf`
  - Team Explorer Everywhere, Microsoft's Java CLI for TFS
  - Requires Java
  - This script assumes `tf` will use saved credentials
  - Initial setup:
    - Download latest from https://github.com/Microsoft/team-explorer-everywhere/releases
    - `export TF_AUTO_SAVE_CREDENTIALS=1`
    - `tf eula -accept`
    - Run any `tf` command, and supply account credentials using the `-login` option, ex. `tf workspaces -collection:https://dev.azure.com/YourCollectionName/ -login:user@domain.com,accesstoken`
3. `jq`
  - Standard JSON query tool
  - Install via your package manager, ex. `apt install jq`
4. `xml2json`
  - Install via `pip install https://github.com/hay/xml2json/zipball/master`
5. `git`

Ensure these prerequisites are under directories in your $PATH

`echo ‘export PATH="/installeddirectory/:$PATH"’ >> ~/.bashrc`

`source ~/.bashrc`


### Step 2: Source TFVC repository path

This script is currently written to only convert a single source path (i.e. single branch or lower) into a single git repo, but building support for multiple branches is on our radar

Choose your path from your TFVC repo, and provide it in the format `$/directory/path`

### Step 3: Choose what to migrate

- History
  - Pick the oldest changeset ID you want migration to start with to retain history; the default behaviour is to retain all history, but this can be quite slow
- `.gitignore`
  - You can create a `.gitignore` file, and pass it in as a command arg. It will be committed to the destination git repo, so the git CLI will apply it to all commits, dropping the matching files from the TFVC repository
  - This is a good way to exclude binary or media files from the git repo

### Step 4: Create a new remote repo

- If you want this script to push the git repo to a remote, provide the full repo URL in the `--remote` arg
- Set up an empty git repository somewhere and copy the remote origin path
- This script assumes the the git CLI already has push access to this remote
- If not, the final stage to push the repo to this remote will fail, the local copy of the git repo is retained

### Step 5: Map TFS changeset owner names to Git author names

- TFS repo metadata stores authors according to your authentication scheme, ex. `user@domain.com` or `domain\username`
- These need to be mapped to proper git author tags, ex. `First Last <first.last@domain.com>`
- Ex.
```json
{
    "first.last@domain.com": "First Last <first.last@domain.com>",
    ...
}
```

### Step 6: Run

Run the script without arguments to view the manual.

```bash
./tfs-to-git.sh \
  --authors ./authors.json \
  --batch-size 10 \
  --collection "https://dev.azure.com/YourCollectionName" \
  --remote "https://github.com/org/repo"  \
  --source "$/directory/path" \
  --target ./.repos/org/repo
```

## Notes

1. This can take quite a while. In a test run, a migration of 3500 changesets with 800 MB of content took 10 hours to complete.

2. Original changeset dates will be preserved, and set as both git author and commit dates.
