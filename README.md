# TFS to Git Conversion Tool

- TFVC repo goes in, Git repo comes out
- Forked from https://github.com/turbo/gtfotfs, then substantially refactored
- Runs on Bash v4, so it doesn't require Windows like git-tfs
- Doesn't run on Apple Silicon Macs until https://github.com/microsoft/team-explorer-everywhere/issues/334 is resolved
- Developed and tested on Ubuntu, YMMV

## How to Migrate TFVC Repos to Git

### Step 1: Install and configure prerequisites

Instructions provided for Ubuntu

1. Ensure OS packages are up to date
  - `sudo apt update`
  - `sudo apt upgrade`

2. `git`
  - Standard git CLI
  - `sudo apt install git`

3. `jq`
  - Standard JSON query tool
  - `sudo apt install jq`

4. `pip`
  - Python package manager, required for `xml2json`
  - `sudo apt install python3-pip`

5. `xml2json`
  - Required because the only machine-readable output format available in the tf CLI is XML
  - `sudo -H` is required to ensure that `xml2json` is installed in a path reachable by all users
  - `sudo -H pip install https://github.com/hay/xml2json/zipball/master`

6. Java
  - Required runtime environment for `tf`
  - `sudo apt install default-jre`

7. Unzip
  - Required to unzip the `tf` download
  - `sudo apt-get install unzip`

8. `tf`
  - Team Explorer Everywhere, Microsoft's Java (cross-platform) CLI for TFS
  - `tfs-to-git.sh` makes use of `tf`'s saved credentials feature
    - Which caches a session token in plaintext somewhere under `~/.microsoft/Team\ Foundation/4.0/Cache/`
    - Be sure to use an access token with least privileges
  - Create a Personal Access Token in a service account's Azure DevOps settings, with required permissions:
    - If you are hosting the converted Git repo somewhere else, then you only need `"Code: Read"` permissions on this Azure DevOps token
    - If you prefer to host the converted Git repo in the same Azure DevOps project to maintain the same user permissions to the repo, and enable Sourcegraph integration, then you'll need `Code: Write and Manage` permissions
  - Download latest TEE-CLC-[version].zip from https://github.com/Microsoft/team-explorer-everywhere/releases
  - `wget https://github.com/microsoft/team-explorer-everywhere/releases/download/14.139.0/TEE-CLC-14.139.0.zip`
  - `unzip TEE-CLC-14.139.0.zip`
  - `mv ./TEE-CLC-14.139.0 /directory/in/all/users/$PATH`
  - Initial setup, either:
      - Provide your Azure DevOps username and access token (not password) the first time you run the script, via environment variables or script args, so the script can handle this part for you
      - Or, if you prefer to prevent your access token from getting recorded in ~/.history, login interactively before running the script:
```bash
# Export this environment variable, so the tf client knows to cache an auth token
export TF_AUTO_SAVE_CREDENTIALS=1

# Must accept the eula before running any other tf command
tf eula -accept

# Run any tf command that will reach your collection
tf workspaces -collection:https://dev.azure.com/{YourOrg}/ -login:user@domain.com,accesstoken

# Or, to avoid recording your token in your shell history, run any tf command, and provide username and access token when prompted
tf workspaces -collection:https://dev.azure.com/{YourOrg}/
Default credentials are unavailable because no Kerberos ticket or other authentication token is available.
Username: marc.leblanc@sourcegraph.com
Password:
No workspace matching *;User Name on computer hostname found in Team Foundation Server https://dev.azure.com/{YourOrg}.
```

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
- In JSON format, so if your TFS server uses the `domain\user` scheme, you'll need to escape the `\` with a second `\`
- To make this easier for you, if you run the script for the first time with a `--batch-size` larger than your commit history, the script will pull the metadata for all changesets in the repo's / path's history, and will output a `-missing-authors.json` file with the list of all unique changeset owner's user IDs. They all need to be mapped, otherwise the conversion will fail when it finds a changeset with an unmapped author.
- Ex. `./authors.json` file contents
```json
{
    "first.last@domain.com": "First Last <first.last@domain.com>",
    "domain\\first.last": "First Last <first.last@domain.com>",
    ...
}
```


### Step 5: Run

Run the script without arguments to view the current / full list of parameters

## Notes

1. This can take quite a while. In a test run, a migration of 3500 changesets with 800 MB of content took 10 hours to complete.

2. Original changeset dates will be preserved, and set as both git author and commit dates.

3. To get the number of changesets in the history of a file path, run the script at that source path, with a large number (up to 64 bit signed integer) for the `--batch-size` argument, wait for it to pull the history file, and output `Changesets received in this batch: x`, then Ctrl + c to quit the script. ex:
```bash
./tfs-to-git.sh \
  --force-replace \
  -c COLLECTION \
  -s $/project/source/path \
  --batch-size 9223372036854775807
```
