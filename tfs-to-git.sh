#!/usr/bin/env bash

# TODO:
    # How will the customer want to use this script?

        # This isn't like Git, where you could just provide an Org (collection), and it could query the API to get a list of all repos, and clone them
            # Customer admins need to make decisions about which source paths they want to migrate
                # Or, do they?
                # I need to provide a sane default
            # Can we assume a source path of $/ for all Collections, unless otherwise provided?
                # This would result in all branches getting committed to the main branch of the git repo, just in different subdirectory trees
                # There's no way to avoid this, without the customer providing a list of $/source/paths for their main and other branches

        # Chances are the customer just wants to provide:
            # - A list of TFS / ADO servers
                # - One or more access token per server
            # - A list of collections per server
                # - Or is there an API to get a list of all collections on the server?
            # - A list of source paths per collection
                # - TFS only supports once TFVC repo per collection, but users may want to convert multiple branches, or subdirectory locations
            # - Branch mode
                # - 1:1 repo and branch mapping
                    # - Could be automated if there was a consistent way to know where in the file path is each branch
                    # - Otherwise requires the user to provide a branch map of source paths for each main / branch
            # - A git remote for each of these ^
                # - I'd rather just provide
                    # - One Git server
                        # Either just one Git org, or one org per Collection
                        # Then have the script use the collection / source path as the repo name
            # - Assume that either:
                # A) git remote repos are 1:1 with TFVC collections (branch mode)
                    # i.e. if they want to migrate 3 branches, this results in 3 branches inside of 1 git repo
                    # This would require building support for branches
                # B) git remote repos are 1:1 with TFVC branches
                    # One TFVC branch per Git repo
                    # i.e. they probably only want to migrate their main branch, or their TFVC branching strategy doesn't carry over into Git, so they are rethinking it in the migration process
                    # i.e. if they want to migrate 3 branches, this results in 3 separate git repos

    # Git repo naming
        # I think, by default, git init creates a repo named just with the current working directory
        # The git remote determines the repo's name on their git server
        # But, if we're just using src serve-git, then the repo name is actually the file path below the root directory of where src serve git is traversing from
            # ex. if running src serve-git from /sourcegraph/tfs-to-git/.repos, and there are repos below this direcotry at orgs/repos, then the repo's name is org/repo, but there's no code host FQDN/org path to it, so the directory tree is key.
        # Assume we'll be running src serve-git from /sourcegraph/tfs-to-git/.repos
        # repositoryPathPattern isn't used for src serve-git
        # Should name the repo server/collection-source-path by default, especially if cloning $/ root
            # For Branch Mode, the user will probably want the repo to be named after the collection, because the source paths are just branch names
        # So in the end
            # Default repo names: collection-source-path
            # Assume that we don't need to use the git remote in the file path
            # replace '/' with '-' for collection and $/source/path
            # File tree:
            # ./repos/tfs_server/collection-source-path/
                # .git (repo)
                # .tfs-to-git/ (working files)

    # Check tf workspace before recreating it

    # Fix jq query to accommodate the scenario where the XML to JSON conversion results in a single JSON object instead of an array, because there's only one changelist to sync
        # It seems like $tfs_changeset_sequence is supposed to be an array of changset IDs? but when there's only 1 ID in the variable, it's not an array?

        # Might need to refactor load_tfs_changeset_sequence_old_to_new to return an array even if there's only 1 element

        # while read -r current_changeset_id
        # done <<<"$tfs_changeset_sequence"

        # 2024-01-23;02:33:44;tfs-to-git;v0.2;INFO;Downloading changeset [ from TFS [0 remaining]:
        # Author:  marc.leblanc@sourcegraph.com -> Marc LeBlanc <marc.leblanc@sourcegraph.com>
        # Date:    2024-01-08T22:15:39.547+0000
        # Message: Created team project folder $/marc-test-tfvc via the Team Project Creation Wizard

        # An argument error occurred: Option 'version' requires a version spec as its value: The changeset version specification was not recognized as a number.
        # Team Explorer Everywhere Command Line Client (version 14.139.0.202310311513)

        #  get command:


    # Missing authors
        # Add all missing authors to the authors file, in a format that's easy for the admin to fill in

    # Update readme
        # Provide thorough dependency installation instructions
        # Fix bug with target path not being able to be a cousin directory, or document it in the README and usage text

    # Exit 3 if there are more changes left after the batch size is exhausted
        # So the calling script knows to call it again sooner than having to wait for the next interval

    # Add stats for download times and storage size, number of changed files
        # Cleanup and exit function prints stats for changesets processed, total changed files, total MB downloaded, repo size, time spent downloading, execution time

    # Sort out local git config
        # Reconfigure committer user.name/email based on author mapping

    # Test connectivity to endpoints before beginning
        # If Git remote is provided, test its connection during input validation (ie. git can access credentials, start a session, network connectivity, etc.)

    # Sort out credential handling
        # Git PAT if provided
        # tf -login if username / password provided
        # Environment variables

    # Rewrite in Go / Python?
        # Use a high performance git library
        # Go may make it easier to get integrated into the product, so then we get the added benefits of perms syncing, etc.

    # Branch mode
        # Would take a bunch more time, so we'd need to validate that with the customer before spending that time on it
        # Might name the git repo after the collection name

    # In the calling script, take list of repos as an arg in the code hosts yaml file
        # Default “all”
        # Parallelize by running on multiple repos at a time


# Declare global variables
# declare -A is an associative array
# declare -i is an integer variable
# declare -r is a read-only variable
declare -A  author_mapping_array
declare     author_name_mapping_file
declare -i  changelist_batch_size=100
declare -i  continue_from_changeset
declare -i  exit_status=0
declare -A  external_dependencies_array
declare     force_replace_git_target_directory=false
declare     git_default_branch="main"
declare     git_default_committer_email="tfs-to-git@sourcegraph.com"
declare     git_default_committer_name="TFS-to-Git"
declare     git_force_push=false
declare     git_ignore_content=".tf* \n.tfs-to-git"
declare     git_ignore_file
declare     git_remote
declare     git_target_directory
declare     git_target_directory_root
declare     initial_pwd
declare -i  last_commit_changeset
declare     log_level_config="INFO"
declare     log_level_event="INFO"
declare -Ar log_levels=([DEBUG]=0 [INFO]=1 [WARNING]=2 [ERROR]=3)
declare -a  missing_authors
declare     missing_dependencies
declare -r  script_name="tfs-to-git"
declare     log_file="./$script_name.log"
declare -r  script_version="v0.2"
declare -a  tfs_changeset_sequence
declare     tfs_collection
declare -i  tfs_history_start_changeset=1
declare     tfs_latest_changeset_json
declare     tfs_latest_changeset_xml
declare     tfs_repo_history_file_json
declare     tfs_repo_history_file_xml
declare     tfs_server="https://dev.azure.com"
declare     tfs_source_repo_path="$/"
declare -r  tfs_workspace="tfs-to-git-migration"
declare     validate_paths=false
declare     working_files_directory

# Colours for formatting stdout
declare -r  error_red_colour='\033[0;31m'
declare -r  info_yellow_colour='\033[0;33m'
declare -r  reset_colour='\033[0m'

# Environment variables used because Git doesn't allow setting committer date by command line args
# export GIT_AUTHOR_DATE="$current_changeset_date"
# export GIT_COMMITTER_DATE=$GIT_AUTHOR_DATE


function cleanup_and_exit() {

    # Unset environment variables
    unset GIT_COMMITTER_DATE
    unset GIT_AUTHOR_DATE

    # Use whatever was last set as the exit status
    exit "$exit_status"

}


function log() {

    # Set colour for stdout based on log level
    case $2 in
        "DEBUG")
            log_level_event="DEBUG"
            colour=$info_yellow_colour
            ;;
        "INFO")
            log_level_event="INFO"
            colour=$info_yellow_colour
            ;;
        "ERROR")
            log_level_event="ERROR"
            colour=$error_red_colour
            ;;
        *)
            log_level_event="DEBUG"
            colour=$reset_colour
            ;;
    esac

    # If this log event level is not greater than or equal to the configured level, then don't log it
    if [[ ! "${log_levels[$log_level_event]}" -ge "${log_levels[$log_level_config]}" ]]
    then
        return
    fi

    # Common preamble
    log_preamble="$(date +'%F;%T');$script_name;$script_version"

    # Print to stdout
    echo -e "$colour$log_preamble;$log_level_event;$reset_colour$1"

    # # Print to log file
    # echo "$log_preamble;$log_level_event;$1" &>> "$log_file"

}


function debug() {

    # Pass on the message and set the log level
    log "$1" "DEBUG"

}


function info() {

    # Pass on the message and set the log level
    log "$1" "INFO"

}


function warning() {

    # Pass on the message and set the log level
    log "$1" "WARNING"

}


function error() {

    # Pass on the message and set the log level
    log "$1" "ERROR"

    # Exit the script, all errors are fatal
    exit_status=1
    cleanup_and_exit

}


function pushd_popd_cd_error() {

    error "pushd, popd, or cd failed. Directory stack: \n $(dirs -v)"

}


function print_usage_instructions_and_exit() {

    cat <<EOF

    $script_name $script_version
    https://github.com/sourcegraph/tfs-to-git

    Usage:

    ./$script_name.sh -a AUTHORS.json -t TFS_SERVER -c COLLECTION -s SOURCE_PATH

    Arguments:

    -a, --authors
        JSON file to map TFS owner names to git author tags
        Default: ./authors.json

    -b, --batch-size
        Max number of changesets to process in a single run
        Default: 100

    -c, -collection, --collection, --tfs-collection
        [Required]
        TFS collection which contains the source repo
        Does not include the TFS server hostname,
        Ex. YourCollectionName

    -d, --dependencies, --check-dependencies
        Check depdencies and outputs versions, then exits

    -f, --git-push-force, --git-force-push

    -fp, --git-push-force,  --git-force-push
        Enables git push --force to overwrite the remote git repo if it already
        exists

    -fr | --force-replace
        Deletes and recreates the local clone of the repo

    -h, --help
        Print this help message

    --history, --history-start-changeset
        [Optional for new repos, ignored for updating existing repos]
        TFS changeset ID number to start migrating commit history from
        Default: earliest changeset in source repo history

    -i, --git-ignore-file
        .gitignore file for the target git repo

    -l, --log-level
        DEBUG | INFO | WARNING | ERROR
        All errors terminate the script
        Default: INFO

    -r, --remote, --git-remote
        git remote origin
        If provided, the target Git repo will be pushed to this remote at the
        end of the script run
        Ex. https://github.com/YourOrgName/SuperApp

    -s, --source, --tfs-source-path
        Source location within TFS collection
        Ex. "$/directory/path"
        Default: $/

    -t, --tfs, --tfs-server
        Hostname of your TFS / Azure DevOps server
        Default: https://dev.azure.com

    -v, --version
        Print the script version and exit

EOF

    exit_status=0
    cleanup_and_exit

}


function parse_and_validate_user_args() {

    # If the user didn't provide any args, print usage instructions then exit
    if [[ $# -eq 0 ]]
    then
        print_usage_instructions_and_exit
    fi

    # Parse user arguments
    while [[ "$#" -gt 0 ]]
    do
        case $1 in
        -a | --authors)
            author_name_mapping_file="$2"
            shift
            shift
            ;;
        -b | --batch-size)
            changelist_batch_size="$2"
            shift
            shift
            ;;
        -c | -collection | --collection | --tfs-collection)
            tfs_collection="$2"
            shift
            shift
            ;;
        -d | --dependencies | --check-dependencies)
            check_dependencies "arg"
            shift
            shift
            ;;
        -fp | --git-push-force | --git-force-push)
            git_force_push=true
            shift
            ;;
        -fr | --force-replace)
            force_replace_git_target_directory=true
            shift
            ;;
        -h | --help)
            print_usage_instructions_and_exit
            ;;
        --history | --history-start-changeset)
            tfs_history_start_changeset="$2"
            shift
            shift
            ;;
        -i | --git-ignore-file)
            git_ignore_file="$2"
            shift
            shift
            ;;
        -l | --log-level)
            log_level_config="$2"
            shift
            shift
            ;;
        -p | --validate-paths)
            validate_paths=true
            shift
            ;;
        -r | --remote | --git-remote)
            git_remote="$2"
            shift
            shift
            ;;
        -s | --source | --tfs-source-path)
            tfs_source_repo_path="$2"
            shift
            shift
            ;;
        -t | --tfs | --tfs-server)
            tfs_server=$2
            shift
            shift
            ;;
        -v | --version)
            info "$script_name version $script_version"
            exit_status=0
            cleanup_and_exit
            ;;
        *)
            error "Unknown parameter: $1"
            ;;
        esac done

    # If log_level_config is not one of the valid options, error
    if [[ ! ${log_levels[$log_level_config]} ]]; then error "Log level (-l) must be one of ${!log_levels[*]}" ; fi

    # Validate required arguments
    if [ -z "$tfs_server" ];                then error "TFS server (-t) is required"                 ; fi
    if [ -z "$tfs_collection" ];            then error "Collection (-c) is required"                 ; fi
    if [ -z "$tfs_source_repo_path" ];      then error "TFS source repository path (-s) is required" ; fi
    if [ -z "$author_name_mapping_file" ];  then error "Author name mapping file (-a) is required"   ; fi

}


function set_file_paths_before_parsing_user_args(){

    initial_pwd=$(pwd)
    author_name_mapping_file="$initial_pwd/authors.json"

}


function set_file_paths_after_parsing_user_args(){

    git_target_directory_root=".repos"
    working_files_directory=".tfs-to-git"

    # Cobble together the git_target_directory from the provided and/or default args
    # Sanitize for use in file paths
    # Server
    tfs_server="${tfs_server%/}"                        # Remove the trailing slash if provided. Applies to both usages of tfs_server, connection and file path
    tfs_server_for_path="${tfs_server##*://}"           # Remove everything before and including '://'
    # Collection
    tfs_collection_for_path="${tfs_collection//\//-}"   # Replace all '/' with '-'
    # Source path
    tfs_source_repo_path_for_path="${tfs_source_repo_path//\$\/}"           # Remove all '$/'
    tfs_source_repo_path_for_path="${tfs_source_repo_path_for_path//\//-}"  # Replace all '/' with '-'
    # Assemble the git target directory path
    git_target_directory=$initial_pwd/$git_target_directory_root/$tfs_server_for_path/$tfs_collection_for_path

    # If tfs_source_repo_path_for_path is not empty, then append it to git_target_directory
    # To avoid a trailing - if the repo path is the default $/ root
    if [[ -n $tfs_source_repo_path_for_path ]]
    then

        git_target_directory+="-$tfs_source_repo_path_for_path"

    fi

    # Derive file paths and names for working files
    # tf assumes all paths are relative to the working directory
    # The script cd's into git_target_directory before these are used, so assume they are relative to git_target_directory
    tfs_repo_history_file_json="$working_files_directory/repo-history.json"
    tfs_repo_history_file_xml="$working_files_directory/repo-history.xml"
    tfs_latest_changeset_json="$working_files_directory/latest-changeset.json"
    tfs_latest_changeset_xml="$working_files_directory/latest-changeset.xml"


    if $validate_paths
    then

        echo "git_target_directory:         $git_target_directory"
        echo "server/collection/path:       $tfs_server/$tfs_collection/$tfs_source_repo_path"
        echo "tfs_repo_history_file_json:   $tfs_repo_history_file_json"
        echo "tfs_repo_history_file_xml:    $tfs_repo_history_file_xml"
        echo "tfs_latest_changeset_json:    $tfs_latest_changeset_json"
        echo "tfs_latest_changeset_xml:     $tfs_latest_changeset_xml"
        exit_status=0
        cleanup_and_exit

    fi

}


function check_dependencies() {

    info "Checking external dependencies"

    # Add dependencies and their version check commands to the array
    external_dependencies_array+=(["git"]="git --version | sed 's/[^0-9\.]//g'")
    external_dependencies_array+=(["java"]="java --version | head -n 1")
    external_dependencies_array+=(["jq"]="jq --version | sed 's/jq-//g'")
    external_dependencies_array+=(["tf"]="tf | head -n 1 | sed 's/[^0-9\.]//g'")
    external_dependencies_array+=(["xml2json"]="pip list | grep xml2json | sed -nr 's/\S+\s+([0-9\.]+)/\1/p'")

    # Loop through the associative array of external dependencies
    for dependency in "${!external_dependencies_array[@]}"
    do

        # Test if the dependency exists
        if ! hash "$dependency" >/dev/null 2>&1
        then

            # If it doesn't exist, then add it to the missing_dependencies string
            missing_dependencies+=" $dependency\n"

        else

            # If it does exist, and if the user called the script with -d flag, print the version
            if [ -n "$1" ]
            then

                # Get and run the version check command
                info "$dependency $(eval "${external_dependencies_array[$dependency]}")"

            fi

        fi

    done

    # If the missing_dependencies string is not empty
    if [ -n "$missing_dependencies" ]
    then

        path_array=$(echo "$PATH" | tr ':' '\n' | sort )

        # Print all missing dependencies and a helpful message
        error "$(cat << EOF
Dependencies missing or not in your \$PATH
Please see README.md for installation instructions for these dependencies:
$missing_dependencies
Your \$PATH is:
$path_array
EOF
        )"

    fi

    # If the user called the script with the -d flag, none of the dependencies are missing, the versions have been printed, so exit
    if [ -n "$1" ]
    then

        exit_status=0
        cleanup_and_exit

    fi

}


function create_or_update_repo(){

    # If the user provided the --force-replace arg, then try and delete the git_target_directory
    if $force_replace_git_target_directory
    then

        # If the target directory exists, delete it
        if [ -d "$git_target_directory" ]
        then
            info "--force-replace arg specified, $git_target_directory exists, deleting it"
            rm -rf "$git_target_directory" >/dev/null 2>&1
        fi

    fi

    # Check if the target directory exists on disk
    if [ ! -d "$git_target_directory" ]
    then

        # If no, create it
        if ! mkdir -p "$git_target_directory"
        then
            error "Could not create target directory $git_target_directory"
        fi

    fi

    # Change directory to the git_target_directory, for the git commands, and stay in this directory for the rest of the execution
    cd "$git_target_directory" || pushd_popd_cd_error

    # Check if the working files directory exists as a relative path within git_target_directory
    if [ ! -d "$working_files_directory" ]
    then

        # If no, create it
        if ! mkdir -p "$working_files_directory"
        then
            error "Could not create working files directory $working_files_directory"
        fi

    fi

    # Check if the target directory contains a git repo
    if [ -d "$git_target_directory/.git" ]
    then

        # If yes, try and grab the changeset ID number from the latest commit message
        get_latest_changeset_previously_committed

    else

        # If no, initialize the new git repository
        if ! git init
        then
            error "Could not initialize the git repository in $git_target_directory"
        fi

        git_config_global
        create_and_stage_git_ignore_file

    fi

    # If the user provided a git remote in the script args, then configure it
    if [ -n "$git_remote" ]
    then

        # Remove the existing origin from the git repo metadata, if it exists
        git remote rm origin >/dev/null 2>&1

        # Add the provided remote
        if ! git remote add origin "$git_remote"
        then

            # If adding the provided remote fails
            error "Configuring git remote origin failed" 1> /dev/null

        fi

    fi

}


function get_latest_changeset_previously_committed() {

    # Check the output of git log to read the most recent commit message, to extract a changeset ID number to continue from

    # If git repo exists, but has zero commits, this hides an error message
    # fatal: your current branch 'main' does not have any commits yet
    if ! git log -1 --pretty=%s >/dev/null 2>&1
    then
        return
    fi

    # Get just the subject line of the last commit
    # [ADO-6] Added test3
    last_commit_subject_line=$(git log -1 --pretty=%s)

    # If the subject line matches the regex, with the capture group
    last_commit_changeset_regex="^\[ADO-([0-9]+)\]"
    if [[ $last_commit_subject_line =~ $last_commit_changeset_regex ]]
    then

        # Then get the content from the first regex matching capture group
        last_commit_changeset=$(("${BASH_REMATCH[1]}"))
        continue_from_changeset=$((last_commit_changeset+1))

        info "Found latest changeset $last_commit_changeset already committed. Continuing from changeset $continue_from_changeset"

    fi

}


function git_config_global() {

    # Configure Git, to avoid issues and noise
    git config --global init.defaultBranch "$git_default_branch"
    git config --global user.name "$git_default_committer_name"
    git config --global user.email "$git_default_committer_email"

}


function create_and_stage_git_ignore_file() {

    info "Adding initial .gitignore file to exclude working directories"

    # This function is only called when setting up a new git repo, so we're not worried about entering duplicate lines
    # Add .tf to the .gitignore file
    echo -e "$git_ignore_content" >> ".gitignore"

    # If the user provided a file path to a .gitignore file in the script args, cat its contents into the new repo's .gitignore file
    if [ -n "$git_ignore_file" ]
    then
        cat "$git_ignore_file" >> ".gitignore"
    fi

    # Stage the .gitignore file to be committed to the repo
    if ! git add .gitignore
    then
        error "Could not stage .gitignore file. Check git output"
    fi

}


function create_migration_tfs_workspace() {

    info "Creating $tfs_workspace workspace for collection $tfs_server/$tfs_collection"

    # Delete the workspace if it already exists
    tf workspace -delete -noprompt "$tfs_workspace" -collection:"$tfs_server/$tfs_collection" > /dev/null 2>&1

    # Create the workspace for the migration
    # Note that this workspace will continue to exist as created, until this script is run again, which will delete and recreate it
    if ! tf workspace -new -noprompt "$tfs_workspace" -collection:"$tfs_server/$tfs_collection" 1> /dev/null
    then
        error "Failed to create new $tfs_workspace workspace for collection $tfs_server/$tfs_collection"
    fi

    # TFS is different from Perforce, in that a local file path (work folder) can only exist in one workspace at a time
    # Unmap the target directory from any previous workspace, before mapping it to the new location
    tf workfold -unmap -workspace:"$tfs_workspace" "$tfs_source_repo_path"  > /dev/null 2>&1

    # Map the target directory to the workspace
    info "Mapping TFS source $tfs_source_repo_path to Git target directory $git_target_directory"
    if ! tf workfold -map -workspace:"$tfs_workspace" "$tfs_source_repo_path" .
    then
        error "Failed to map TFS source repo to workspace. Check tf output"
    fi

    # Now there should be a folder mapping, otherwise there's trouble
    info "Outputting the folder mapping to visually verify them"
    tf workfold -workspace:"$tfs_workspace"

}


function get_tfs_repo_history() {

    # Changeset ID range formatting
    # "C2~T" # Start at 2, end at latest
    # C is changeset, optional if specifying just a number
    # T is tip, or latest
    # ~ is the range
    # "2~10" # Start at 2, end at 10
    # https://learn.microsoft.com/en-us/azure/devops/repos/tfvc/use-team-foundation-version-control-commands?view=azure-devops#use-a-version-specification-argument-to-specify-affected-versions-of-items

    # If continue_from_changeset is set
    # Then don't bother pulling history from before then
    # And ignore the value the user provided in --history-start-changeset
    if [[ -n $continue_from_changeset ]]
    then
        tfs_history_start_changeset=$continue_from_changeset
    fi

    # Check the latest changeset in the repo
    # Get it in XML
    if ! tf history \
        "$tfs_source_repo_path" \
        -workspace:"$tfs_workspace" \
        -stopafter:1 \
        -recursive \
        -format:xml \
        -noprompt \
        >"$tfs_latest_changeset_xml"
    then
        error "Unable to get latest changeset ID. See tf output"
    fi

    # Convert it to JSON
    if ! xml2json -t xml2json -o "$tfs_latest_changeset_json" "$tfs_latest_changeset_xml"
    then
        error "Unable to convert latest changeset to JSON. See file $tfs_latest_changeset_xml"
    fi

    # Read it from JSON
    if ! tfs_latest_changeset_id=$(jq -r '.history.changeset["@id"]' "$tfs_latest_changeset_json")
    then
        error "Unable to read tf history from $tfs_latest_changeset_json"
    fi

    ## TODO: Take another look at this, I haven't seen it break yet, but the variable names seem crossed
    # If tfs_history_start_changeset -gt latest, then we're already caught up, exit 0
    if [[ "$tfs_history_start_changeset" -gt "$tfs_latest_changeset_id" ]]
    then
        info "Latest changeset from TFS is $tfs_latest_changeset_id, and latest changeset in the Git repo is $last_commit_changeset. No more history to migrate, exiting."
        exit_status=0
        cleanup_and_exit
    fi

    # Set our tfs_history_end_changeset to the start + the batch size
    tfs_history_end_changeset=$((tfs_history_start_changeset + changelist_batch_size - 1))

    # If $tfs_history_end_changeset -gt latest, then set tfs_history_end_changeset=latest
    if [[ "$tfs_history_end_changeset" -gt "$tfs_latest_changeset_id" ]]
    then
        info "Latest changeset from TFS is $tfs_latest_changeset_id, migrating up to latest."
        tfs_history_end_changeset=$tfs_latest_changeset_id
    fi

    info "Getting history of $tfs_source_repo_path, from changeset $tfs_history_start_changeset to changeset $tfs_history_end_changeset; this may take a long time, depending on TFS changeset sizes"

    # Delete any existing history file from previous executions
    rm -f "$tfs_repo_history_file_xml"

    # Download the TFS history in xml format, and output to the $tfs_repo_history_file_xml
    if ! tf history \
        "$tfs_source_repo_path" \
        -workspace:"$tfs_workspace" \
        -version:"$tfs_history_start_changeset~$tfs_history_end_changeset" \
        -recursive \
        -format:xml \
        -noprompt \
        >"$tfs_repo_history_file_xml"
    then
        error "Unable to get TFVC history. See tf output"
    fi

}


function convert_tfs_repo_history_file_from_xml_to_json() {

    # Convert TF's XML file to JSON format to be much easier to work with
    if ! xml2json -t xml2json -o "$tfs_repo_history_file_json" "$tfs_repo_history_file_xml"
    then
        error "Unable to convert history to JSON. See file $tfs_repo_history_file_xml"
    fi

    # Count and print the number of changesets in the TFS repo's history
    # count_of_changesets=$(grep -c "@id" $tfs_repo_history_file_json)
    count_of_changesets=$(jq '.history.changeset | length' "$tfs_repo_history_file_json")
    info "$count_of_changesets changesets in history"

}


function load_tfs_changeset_sequence_old_to_new() {

    # If there's only one changeset in the sequence, it doesn't need to be reversed, and xml2json creates the schema differently
    if [[ $count_of_changesets -eq 1 ]]
    then

        if ! tfs_changeset_sequence+=($(jq -r '[.history.changeset["@id"]]' "$tfs_repo_history_file_json"))
        then

            error "Unable to load the changeset sequence of length 1. See file $tfs_repo_history_file_json"

        fi

    else

        if ! tfs_changeset_sequence+=($(jq -r '[.history.changeset[]["@id"]] | reverse[]' "$tfs_repo_history_file_json"))
        then

            error "Unable to load the changeset sequence in reverse. See file $tfs_repo_history_file_json"

        fi

    fi

}


function map_authors() {

    # Validate that the name mapping JSON file provided in the user args exists
    if [ ! -f "$author_name_mapping_file" ]
    then
        error "Owner mapping file $author_name_mapping_file does not exist, and is required"
    fi

    # TODO: FIX THIS
    # Get a list of unique authors' email addresses from the TFS repo history file
    authors_email_addresses_to_map_from_tfs_history=$(jq -r '[.history.changeset[]["@owner"]] | unique[]' "$tfs_repo_history_file_json")

    # If there's only one changeset in the sequence, xml2json creates the schema differently
    if [[ $count_of_changesets -eq 1 ]]
    then

        if ! authors_email_addresses_to_map_from_tfs_history=$(jq -r '[.history.changeset["@owner"]] | unique[]' "$tfs_repo_history_file_json")
        then

            error "Unable to get the one author's email address from $tfs_repo_history_file_json"

        fi

    else

        if ! authors_email_addresses_to_map_from_tfs_history=$(jq -r '[.history.changeset[]["@owner"]] | unique[]' "$tfs_repo_history_file_json")
        then

            error "Unable to get a list of unique authors' email addresses from $tfs_repo_history_file_json"

        fi

    fi

    # Iterate through the list of authors from the TFS repo history file
    while IFS="" read -r author_to_map_from_tfs_history
    do

        # Use jq to search the $author_name_mapping_file for the author's email address from the TFS repo history file
        author=$(jq -r '.["'"${author_to_map_from_tfs_history//\\/\\\\}"'"]' "$author_name_mapping_file")

        # If jq didn't find this author from the TFS history in the $author_name_mapping_file
        if [ -z "$author" ]
        then

            # Add the author to the list of missing authors
            missing_authors+=("$author")

        else

            # Store the author in the associative array
            author_mapping_array["${author_to_map_from_tfs_history}"]="${author}"

        fi

    # Read the next line from the authors_email_addresses_to_map_from_tfs_history list, from the TFS history
    done < <(tr ' ' '\n' <<<"$authors_email_addresses_to_map_from_tfs_history")

    # If the author name mapping file is missing authors, list them out for the user to add
    if [[ -n "${missing_authors[*]}" ]]
    then

        # TODO: Write all authors from the TFS repo history not found in the author_name_mapping_file
        # back out to the author_name_mapping_file, with friendly formatting,
        # before exiting, so that the user can check the file and fill in all missing authors in one execution,
        # instead of having to re-run this script multiple times to find all the missing authors
        error "Author name mapping file $author_name_mapping_file is missing the below authors; please add them. \n ${missing_authors[*]}"

    fi

    # Output the name mapping to the user for visual verification
    debug "Authors found in TFS repo history and read from $author_name_mapping_file:"
    for author_iterator in "${!author_mapping_array[@]}"
    do
        echo "$author_iterator -> ${author_mapping_array[$author_iterator]}"
    done
    echo ""

}


function migrate_tfs_changesets_to_git_commits() {

    # If continue_from_changeset is set, then this isn't our first commit
    if [[ -n $continue_from_changeset ]]
    then
        first_commit=false
    else
        first_commit=true
    fi

    changesets_remaining=$count_of_changesets

    debug "tfs_changeset_sequence: ${tfs_changeset_sequence[*]}"

    # Iterate through $tfs_changeset_sequence
    while read -r current_changeset_id
    do

        # Read changeset information from the JSON history file
        # If there's only one changeset in the sequence, xml2json creates the schema differently
        if [[ $count_of_changesets -eq 1 ]]
        then

            # Extract fields from the changeset info
            current_changeset_message=$(jq -r '.history.changeset.comment."#text"' "$tfs_repo_history_file_json")
            current_changeset_author=$(jq -r '.history.changeset."@owner"' "$tfs_repo_history_file_json")
            current_changeset_date=$(jq -r '.history.changeset."@date"' "$tfs_repo_history_file_json")

        else

            if ! current_changeset_info=$(jq -c '.history.changeset[] | select (.["@id"] == "'"$current_changeset_id"'") | [.comment["#text"], .["@owner"], .["@date"]]' "$tfs_repo_history_file_json")
            then

                error "Unable to get current_changeset_info from an array"

            fi

            # Extract fields from the changeset info
            current_changeset_message=$(echo "$current_changeset_info" | jq -r '.[0]')
            current_changeset_author=$( echo "$current_changeset_info" | jq -r '.[1]')
            current_changeset_date=$(   echo "$current_changeset_info" | jq -r '.[2]')

        fi

        # Validate (again) that the author is mapped
        # If the above jq commands fail, then this line will likely fail with a "bad array subscript" error
        if [ -z "${author_mapping_array["$current_changeset_author"]}" ]
        then
            error "Source author $current_changeset_author is not mapped"
        fi

        # Decrement the number of changesets remaining
        ((changesets_remaining--))

        # Print commit details to the user to show progress
        info "Downloading changeset $current_changeset_id from TFS [$changesets_remaining remaining]:"
        echo "Author:  $current_changeset_author -> ${author_mapping_array["$current_changeset_author"]}"
        echo "Date:    $current_changeset_date"
        echo "Message: $current_changeset_message"
        echo ""

        # Sync the files in the changeset from TFS
        if $first_commit
        then

            # On first commit, force the tf get command
            if ! tf get . -recursive -noprompt -version:"C$current_changeset_id" -force
            then
                error "Error while getting first commit. See tf output"
            fi
            first_commit=false

            # An argument error occurred:
            # The workspace could not be determined from any argument paths or the current working directory.
            # It seems like this script cannot be run from a cousin directory, must be run from a parent directory of the git_target_directory

        else

            # On subsequent commits, don't force the tf get command
            if ! tf get . -recursive -noprompt -version:"C$current_changeset_id"
            then
                error "Error while getting current commit. See tf output"
            fi

        fi

        # Using environment variables for the dates, because Git doesn't allow setting GIT_COMMITTER_DATE by CLI arg
        export GIT_AUTHOR_DATE="$current_changeset_date"
        export GIT_COMMITTER_DATE="$current_changeset_date"

        # Stage files to commit
        if ! git add .
        then
            error "Error while staging files. See git output"
        fi

        # Print the new working directory to show where this command is getting run from
        info "Committing changeset $current_changeset_id to git repo"

        # Commit files
        # nothing to commit, working tree clean # Also an error that need to consider
        if ! git commit \
            --all \
            --allow-empty \
            --author="${author_mapping_array["$current_changeset_author"]}" \
            --message="[ADO-$current_changeset_id] $current_changeset_message"
        then
            error "Error while committing changes. See git output"
        fi

        echo ""

    done <<<"$tfs_changeset_sequence"

}


function git_garbage_collection() {

    info "Optimizing repository size by performing git reflog expire and git gc"

    git reflog expire --all --expire=now
    git gc --prune=now --aggressive

}


function git_push() {

    # If no git remote was provided, then skip pushing
    if [[ -z "$git_remote_url" ]]
    then
        return
    fi

    if [ $git_force_push ]
    then

        info "Force pushing to git remote origin"

        if ! git push -u origin --all --force
        then
            error "Error while force pushing to origin. See git output"
        fi

    else

        info "Pushing to git remote origin"

        if ! git push -u origin --all
        then
            error "Error while pushing to origin. See git output"
        fi

    fi

}


function main() {

    set_file_paths_before_parsing_user_args

    parse_and_validate_user_args "$@"

    set_file_paths_after_parsing_user_args

    # Check that all needed dependencies are installed and in $PATH
    check_dependencies

    # If this is a new repo, create it, otherwise grab the latest changeset ID number to continue from
    create_or_update_repo

    # Run the migration process
    create_migration_tfs_workspace
    get_tfs_repo_history
    convert_tfs_repo_history_file_from_xml_to_json
    load_tfs_changeset_sequence_old_to_new
    map_authors
    migrate_tfs_changesets_to_git_commits
    git_garbage_collection
    git_push

    # Cleanup
    exit_status=0
    cleanup_and_exit

}

# Trap if user hits CTRL-C during script
trap "exit_status=1; cleanup_and_exit" SIGHUP SIGINT SIGQUIT SIGPIPE SIGTERM

# Print to both shell and log_file
test -t 1 && { exec $0 "$@" 2>&1 | tee -a "$log_file"; exit; }

# Execute the main function
main "$@"
