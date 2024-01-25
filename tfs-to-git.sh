#!/usr/bin/env bash

# TODO:

    # Improve validation of existing tfs_workfold
        # Remove each matching line from $tfs_workfold
        # Then strip out all non-letter characters
        # Then count the lines remaining
        # If there are more than 0 lines remaining
        # Then there are extra work folder mappings in the workspace

    # Add progress and summary stats
        # Progress stats, per changeset
            # Download sizes, times, and speed (mbps)
            # Processing times and speed (MB/s)
            # Number of changed files
        # Summary stats, per script execution
            # Changesets processed
            # Total download sizes, times, and speed (mbps)
            # Total processing times and speed (MB/s)
            # Total number of changed files
            # Total execution time
            # Repo size
            # Cleanup and exit function prints summary stats

    # Extract project name from $/{project}/ repo source path
        # Use it in the URL

    # Test connectivity to endpoints before beginning
        # If Git remote is provided, test its connection during input validation (ie. git can access credentials, start a session, network connectivity, etc.)

    # In the calling script, take list of repos as an arg in the code hosts yaml file
        # Default “all”
        # Parallelize by running on multiple repos at a time

    # Sort out credential handling
        # Git PAT if provided
        # Environment variables

    # Rewrite in Go / Python?
        # Use a high performance git library
        # Go may make it easier to get integrated into the product, so then we get the added benefits of perms syncing, etc.

    # Branch mode
        # Would take a bunch more time, so we'd need to validate that with customers before spending that time on it
        # Might name the git repo after the collection name

    # How will customers want to use this script?
        # This isn't like Git, where you could just provide an Org (collection), and it could query the API to get a list of all repos, and clone them
            # Customers need to make decisions about which source paths they want to migrate
            # Default source path of $/
                # This results in all branches of all projects in the org getting committed to the main branch of the git repo, just in different subdirectory trees
                # There's no way to avoid this, without the customer providing a list of $/project/source/paths for their main and other branches

        # Chances are the customer just wants to provide:
            # - A list of TFS / ADO servers
                # - One or more access tokens per server
            # - A list of collections per server
                # - Or is there an API to get a list of all collections on the server?
            # - A list of projects per collection
                # - TFS only supports once TFVC repo per collection, so all projects in the collection are just top level folders in the same TFVC repo
                # - Customers may want to convert a subset of projects / branches into a repo
            # - Branch mode
                # - 1:1 repo and branch mapping
                    # - Requires the customer to provide a list of branch source paths for each main / branch
            # - A git remote for each repo
                # - I'd rather just provide
                    # - One Git server
                        # Either just one Git org, or one org per Collection
                        # Then have the script use the collection / source path as the repo name

    # Git repo naming
        # src serve-git names the repo as the file path below the root directory of where src serve git is traversing from
            # ex. if running src serve-git from /sourcegraph/tfs-to-git/.repos, and there are repos below this directory at orgs/repos, then the repo's name is org/repo, but there's no code host FQDN/org path for src serve-git, so add an extra directory level in the repo path mimic a code host FQDN in Sourcegraph
        # Assume we'll be running src serve-git from /sourcegraph/tfs-to-git/.repos
        # repositoryPathPattern isn't available for src serve-git
        # Should name the repo server/collection-source-path by default, especially if cloning $/ root
        # Therefore
            # Default repo names: collection-source-path
            # Assume that we don't need to use a user-provied --git-remote in the file path
            # replace '/' with '-' for collection and $/source/path
            # File tree:
                # ./repos/server/collection-source-path/
                    # .git (repo)
                    # .tfs-to-git/ (script files)
                    # Working copy of the files

# Declare global variables
# declare -a is an array
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
declare     get_repo_size_arg=false
declare     git_default_branch="main"
declare     git_default_committer_email="tfs-to-git@sourcegraph.com"
declare     git_default_committer_name="TFS-to-Git"
declare     git_force_push=false
declare     git_ignore_content=".tf* \n.tfs-to-git"
declare     git_ignore_file
declare     git_remote_url
declare     git_target_directory
declare     git_target_directory_root
declare     initial_pwd
declare -i  last_commit_changeset
declare     log_level_config="INFO"
declare     log_level_event="INFO"
declare -Ar log_levels=([DEBUG]=0 [INFO]=1 [WARNING]=2 [ERROR]=3)
declare -a  missing_authors
declare     missing_authors_file
declare     missing_dependencies
declare -r  script_name="tfs-to-git"
declare     log_file="./$script_name.log"
declare -r  script_version="v0.1"
declare     tfs_access_token_arg
declare     tfs_changeset_id_array
declare     tfs_collection
declare -i  tfs_history_start_changeset=1
declare     tfs_latest_changeset_json
declare     tfs_latest_changeset_xml
declare     tfs_project
declare     tfs_repo_history_file_json
declare     tfs_repo_history_file_xml
declare     tfs_server="https://dev.azure.com"
declare     tfs_source_repo_path="$/"
declare     tfs_source_repo_path_for_url
declare     tfs_username_arg
declare     tfs_workspace
declare     validate_paths=false
declare     working_files_directory

# Colours for formatting stdout
declare -r  error_red_colour='\033[0;31m'
declare -r  info_yellow_colour='\033[0;33m'
declare -r  warning_orange_colour='\033[0;35m'
declare -r  reset_colour='\033[0m'


function cleanup_and_exit() {

    # Unset git environment variables
    unset GIT_AUTHOR_DATE
    unset GIT_AUTHOR_EMAIL
    unset GIT_AUTHOR_NAME
    unset GIT_COMMITTER_DATE
    unset GIT_COMMITTER_EMAIL
    unset GIT_COMMITTER_NAME

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
        "WARNING")
            log_level_event="WARNING"
            colour=$warning_orange_colour
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

    --repo-size
        Force pull the latest revision, without intermediate changesets, and
        output the size of the repo on disk
        This will not commit the files to the git repo, but it also doesn't
        clean them up, so they'll be committed on the next run of the script
        If your repo was not previously at the latest revision, or latest -1,
        this will break your git repo history, so you should re-run the script
        with the -fr args after this finishes, to force replace the git repo
        To avoid this, run this after your repo clone is up to date with
        latest, or before you begin migrating history.

    -s, --source, --tfs-source-path
        Source location within TFS collection
        Ex. "$/directory/path"
        Default: $/

    -t, --tfs, --tfs-server
        Hostname of your TFS / Azure DevOps server
        Default: https://dev.azure.com

    --tfs-token, --tfs-access-token
        Access token of an account on your TFS / Azure DevOps server to
        download repo content.

        TFS access token can also be stored in environment variable TFS_ACCESS_TOKEN
        If provided as both environment variable and command arg, the command
        arg will take precedence

    --tfs-user, --tfs-username
        Login username of an account on your TFS / Azure DevOps server to
        download repo content

        TFS username can also be stored in environment variable TFS_USERNAME
        If provided as both environment variable and command arg, the command
        arg will take precedence

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
            git_remote_url="$2"
            shift
            shift
            ;;
        --repo-size)
            get_repo_size_arg=true
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
        --tfs-token | --tfs-access-token)
            tfs_access_token_arg=$2
            shift
            shift
            ;;
        --tfs-user | --tfs-username)
            tfs_username_arg=$2
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
    tfs_source_repo_path_for_url="${tfs_source_repo_path//\$\/}"           # Remove all '$/'
    tfs_source_repo_path_for_path="${tfs_source_repo_path_for_path//\//-}"  # Replace all '/' with '-'
    # Assemble the git target directory path
    git_target_directory=$initial_pwd/$git_target_directory_root/$tfs_server_for_path/$tfs_collection_for_path

    # Set the name of the TFS workspace to use for migration based on user inputs
    # to avoid conflicting workspace names when processing multiple branches of the same collection in parallel
    # $tfs_workspace naming conflicts
        # Could be running many parallel executions for different paths / branches in the same collection
        # Could be running many parallel executions for different collections on the same server
    # Error TF10131: workspace name
        # contains more than 64 characters
        # contains one of the following characters: "/:<>\|*?;
        # or ends with a space
    tfs_workspace="t2g-$tfs_collection_for_path"

    # If tfs_source_repo_path_for_path is not empty, then append it to git_target_directory
    # To avoid a trailing - if the repo path is the default $/ root
    if [[ -n $tfs_source_repo_path_for_path ]]
    then

        git_target_directory+="-$tfs_source_repo_path_for_path"
        tfs_workspace+="-$tfs_source_repo_path_for_path"

    fi

    # Derive file paths and names for working files
    # tf assumes all paths are relative to the working directory
    # The script cd's into git_target_directory before these are used, so assume they are relative to git_target_directory
    tfs_repo_history_file_json="$working_files_directory/repo-history.json"
    tfs_repo_history_file_xml="$working_files_directory/repo-history.xml"
    tfs_latest_changeset_json="$working_files_directory/latest-changeset.json"
    tfs_latest_changeset_xml="$working_files_directory/latest-changeset.xml"

    missing_authors_file="$initial_pwd/$tfs_server_for_path-$tfs_collection_for_path-missing-authors.json"

    tfs_path_url="$tfs_server/$tfs_collection/$tfs_project/_versionControl?path=$/$tfs_project/$tfs_source_repo_path_for_url"
    # https://dev.azure.com/marc-leblanc/test2/_versionControl?path=$/test2/README.md
    # https://dev.azure.com/marc-leblanc/marc-test-tfvc/_versionControl?path=$/marc-test-tfvc/app/main/dev/README.md

    # If the user provided the --validate-paths flag
    if $validate_paths
    then

        echo "Validating paths"
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
        if git init >/dev/null 2>&1
        then
            info "Initializing new git repository in $git_target_directory"
        else
            error "Could not initialize new git repository in $git_target_directory"
        fi

        git_config_global
        create_and_stage_git_ignore_file

    fi

    # If the user provided a git remote in the script args, then configure it
    if [ -n "$git_remote_url" ]
    then

        # Remove the existing origin from the git repo metadata, if it exists
        git remote rm origin >/dev/null 2>&1

        # Add the provided remote
        if ! git remote add origin "$git_remote_url"
        then

            # If adding the provided remote fails
            error "Configuring git remote origin failed" 1> /dev/null

        fi

    else
        # If the user did not provide a git remote in the script args, check if one is already configured
        if ! git_remote_url=$(git config --get remote.origin.url)
        then

            debug "Couldn't get git config --get remote.origin.url from the repo"

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

        info "Found existing repo at $git_target_directory, with last committed changeset $last_commit_changeset"

    fi

}


function git_config_global() {

    # Configure Git, to avoid issues and noise
    git config --global init.defaultBranch "$git_default_branch"
    git config --global user.name "$git_default_committer_name"
    git config --global user.email "$git_default_committer_email"

}


function create_and_stage_git_ignore_file() {

    info "Creating .gitignore file"

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


function tfs_login() {

    declare tfs_username
    declare tfs_access_token
    declare creds_provided

    # Export the TF_AUTO_SAVE_CREDENTIALS variable, so that the tf command will save credentials in memory for the rest of the script execution
    export TF_AUTO_SAVE_CREDENTIALS=1

    # Accept the EULA
    tf eula -accept > /dev/null 2>&1

    # If ENV variables are set
    if [[ -n "$TFS_USERNAME" ]]
    then

        # Read ENV variables
        debug "TFS_USERNAME is set"
        tfs_username="$TFS_USERNAME"
        creds_provided+="TFS_USERNAME "

    fi

    # If command args are set
    if [[ -n "$tfs_username_arg" ]]
    then

        # Read command args
        # Overwrite ENV variables if both are set
        debug "--tfs-username is set"
        tfs_username="$tfs_username_arg"
        creds_provided+="--tfs-username "

    fi

    # If ENV variables are set
    if [[ -n "$TFS_ACCESS_TOKEN" ]]
    then

        # Read ENV variables
        debug "TFS_ACCESS_TOKEN is set"
        tfs_access_token="$TFS_ACCESS_TOKEN"
        creds_provided+="TFS_ACCESS_TOKEN "

    fi

    # If command args are set
    if [[ -n "$tfs_access_token_arg" ]]
    then

        # Read command args
        # Overwrite ENV variables if both are set
        debug "--tfs-access-token is set"
        tfs_access_token="$tfs_access_token_arg"
        creds_provided+="--tfs-access-token"

    fi

    # If both username and access token are provided
    if [[ -n "$tfs_username" ]] && [[ -n "$tfs_access_token" ]]
    then

        # Try logging in
        if ! tf workspaces \
                -collection:"$tfs_server/$tfs_collection" \
                -login:"$tfs_username,$tfs_access_token" > /dev/null 2>&1
        then

            warning "Failed to login to TFS with provided username $tfs_username and access token"

        fi

    elif [[ -n "$tfs_username" ]] || [[ -n "$tfs_access_token" ]]
    then

        warning "Missing TFS username or password. Credentials provided: $creds_provided"

    fi

}


function create_migration_tfs_workspace() {

    # Booleans for each stage
    workspace_exists=false
    workspace_is_valid=true

    # To be valid, tfs_workfold must contain all matches

    # Get the existing workfolder
    # Workspace:  $tfs_workspace
    # Collection: $tfs_server/$tfs_collection
    #  $tfs_source_repo_path: $git_target_directory
    tfs_workfold=$(tf workfold \
                        -collection:"$tfs_server/$tfs_collection" \
                        -workspace:"$tfs_workspace" 2> /dev/null
                    )

    debug "tfs_workfold received from $tfs_workspace workspace:\n$tfs_workfold"

    # If $tfs_workfold contains
    # The workspace 'test' could not be found.
    # Then the workspace doesn't exist, create it
    if [[ "$tfs_workfold" == *"could not be found"* ]]
    then
        # The workspace doesn't exist, skip the rest of checking, and create it
        info "$tfs_workspace is missing, creating it. \n $tfs_workfold"
        workspace_exists=false
    else
        debug "Workspace already $tfs_workspace exists"
        workspace_exists=true
    fi

    # Only check if the workspace is valid if it exists
    if $workspace_exists
    then

        # Assemble an array of the lines the workfold must contain to be valid
        tfs_workfold_parameters=(
            "$tfs_workspace"
            "$tfs_server/$tfs_collection"
            "$tfs_source_repo_path: $git_target_directory"
        )

        debug "tfs_workfold_parameters required to be valid: ${tfs_workfold_parameters[*]}"

        # Loop through the array of lines and check if each is in the workfold
        for line in "${tfs_workfold_parameters[@]}"
        do

            if [[ "$tfs_workfold" != *"${line}"* ]]
            then

                debug "Line missing from the $tfs_workspace workspace:\n$line"
                workspace_is_valid=false

            # else
                # Improve validation of existing tfs_workfold
                    # Remove each matching line from $tfs_workfold
                    # Then strip out all non-letter characters
                    # Then count the lines remaining
                    # If there are more than 0 lines remaining
                    # Then there are extra work folder mappings in the workspace

            fi

        done

    fi

    # If the workspace exists and is valid, then we're good to return and continue to use the existing workspace
    if $workspace_exists && $workspace_is_valid
    then
        info "Reusing the existing $tfs_workspace workspace"
        return
    fi

    # If the workspace exists but is not invalid, then delete it
    if $workspace_exists && ! $workspace_is_valid
    then

        warning "$tfs_workspace exists and is invalid, deleting it. \n $tfs_workfold"

        # Delete the workspace
        tf workspace \
            -delete \
            "$tfs_workspace" \
            -collection:"$tfs_server/$tfs_collection" \
            -noprompt > /dev/null 2>&1

    fi

    # Create the workspace for the migration
    # Note that this script leaves the workspaces existing after the script finishes
    if ! tf workspace \
            -new \
            "$tfs_workspace" \
            -collection:"$tfs_server/$tfs_collection" \
            -noprompt > /dev/null 2>&1
    then
        error "Failed to create new $tfs_workspace workspace for $tfs_server/$tfs_collection"
    fi

    # TFS is different from Perforce, in that a source path can only exist in one workspace (i.e. one local target directory) at a time
    # Unmap the source path from any previous workspace, before mapping it to the target directory
    # Skip this part, it wastes time, and should never be needed; it's okay to error out if it was needed
    # tf workfold -unmap -workspace:"$tfs_workspace" "$tfs_source_repo_path"  > /dev/null 2>&1

    # Map the target directory to the workspace
    debug "Mapping TFS source $tfs_source_repo_path to Git target directory $git_target_directory"
    if ! tf workfold \
            -collection:"$tfs_server/$tfs_collection" \
            -workspace:"$tfs_workspace" \
            -map \
            "$tfs_source_repo_path" .
    then
        error "Failed to map TFS source repo to workspace. Check tf output"
    fi

    # Now there should be a folder mapping, otherwise there's trouble
    if [[ $log_level_config == "DEBUG" ]]
    then
        debug "Outputting the folder mapping to visually verify them"
        tf workfold \
            -collection:"$tfs_server/$tfs_collection" \
            -workspace:"$tfs_workspace"
    fi

}

function get_repo_size() {

    info "Getting the repo size, this will tf get -force the latest revision, without intermediate changesets, but won't commit these files to teh git repo, so this will break your converted repo history the next time the script is run; you should run the script again with -fr to force replace the git repo after this finishes"

    # Get the lastest version of all files in the workspace
    if ! tf get . \
            -collection:"$tfs_server/$tfs_collection" \
            -workspace:"$tfs_workspace" \
            -version:T \
            -force \
            -recursive \
            -noprompt
    then
        error "Error while getting the latest version of all files in the workspace to check repo size"
    fi

    # Output the repo size
    info "Repo size: $(du -sch *)"

    exit_status=0
    cleanup_and_exit

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
    # This will always be a single object in the XML output
    if ! tf history \
        "$tfs_source_repo_path" \
        -collection:"$tfs_server/$tfs_collection" \
        -workspace:"$tfs_workspace" \
        -stopafter:1 \
        -format:xml \
        -recursive \
        -noprompt \
        >"$tfs_latest_changeset_xml"
    then
        error "Unable to get latest changeset ID. See tf output"
    fi

    # Convert it to JSON
    if ! xml2json -t xml2json --pretty --strip_text -o "$tfs_latest_changeset_json" "$tfs_latest_changeset_xml"
    then
        error "Unable to convert latest changeset to JSON. See file $tfs_latest_changeset_xml"
    fi

    # Read it from JSON
    # Because this is always a single object in the XML output, it's also a single object in JSON, not a list of changeset objects
    # So, just read the JSON as a single object
    if ! tfs_latest_changeset_id=$(jq -r '.history.changeset["@id"]' "$tfs_latest_changeset_json")
    then
        error "Unable to read tf history from $tfs_latest_changeset_json"
    fi

    info "Latest changeset on TFS server is $tfs_latest_changeset_id, $tfs_path_url"

    # If tfs_history_start_changeset -gt latest, then we're already caught up, exit 0
    if [[ "$tfs_history_start_changeset" -gt "$tfs_latest_changeset_id" ]]
    then

        info "No newer changesets to migrate, exiting"

        exit_status=0
        cleanup_and_exit
    fi

    info "Batch size is $changelist_batch_size"

    # Set our tfs_history_end_changeset to the start + the batch size
    tfs_history_end_changeset=$((tfs_history_start_changeset + changelist_batch_size - 1))

    # If $tfs_history_end_changeset -ge latest, then set tfs_history_end_changeset=latest
    if [[ "$tfs_history_end_changeset" -ge "$tfs_latest_changeset_id" ]]
    then

        info "Migrating to latest"
        tfs_history_end_changeset=$tfs_latest_changeset_id

    else

        info "Migrating up to changeset $tfs_history_end_changeset in this batch"
        # Set the exit status to 3, so that the calling script knows that more changesets remain to be migrated, and can call the script to run the next batch sooner than the next interval
        exit_status=3

    fi

    info "Getting changeset history metadata for $tfs_source_repo_path, from changeset $tfs_history_start_changeset to changeset $tfs_history_end_changeset, this may take more time for larger batches"

    # Delete any existing history file from previous executions
    rm -f "$tfs_repo_history_file_xml"

    # Download the TFS history in xml format, and output to the $tfs_repo_history_file_xml
    if ! tf history \
        "$tfs_source_repo_path" \
        -collection:"$tfs_server/$tfs_collection" \
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

    # Add an extra <changeset></changeset> object to the tfs_repo_history_file_xml file, so that xml2json will always convert it to a JSON array rather than a single object
    sed -i 's/^<\/history>$/<changeset><\/changeset><\/history>/' $tfs_repo_history_file_xml

    # Convert tf's XML file to JSON format to be much easier to work with
    if ! xml2json -t xml2json --strip_text -o "$tfs_repo_history_file_json" "$tfs_repo_history_file_xml"
    then
        error "Unable to convert history to JSON. See file $tfs_repo_history_file_xml"
    fi

    # Remove the null line created by xml2json for our sed line insert
    sed -i 's/}, null]}/}]}/' $tfs_repo_history_file_json

    # Count and print the number of changesets in the TFS repo's history
    count_of_changesets=$(jq '.history.changeset | length' "$tfs_repo_history_file_json")
    info "Changesets received in this batch: $count_of_changesets"

    # tf provides the XML in reverse chronological order, so we need to reverse it into chronological order for Git
    # Store this in the array that the big commit conversion loop goes through
    if ! mapfile -t tfs_changeset_id_array < <(jq -r '[.history.changeset[]["@id"]] | reverse[]' "$tfs_repo_history_file_json" 2> /dev/null)
    then

        error "Unable to load the changeset sequence in reverse. See file $tfs_repo_history_file_json"

    fi

}


function map_tfs_owners_to_git_authors() {

    # Verify the name mapping JSON file provided in the user args exists
    if [ ! -f "$author_name_mapping_file" ]
    then
        error "Owner mapping file $author_name_mapping_file does not exist, and is required"
    fi

    # Get a the list of unique changeset owners from the history file
    mapfile -t changeset_owner_usernames_from_tfs_history < <(jq -r '[.history.changeset[]["@owner"]] | unique[]' "$tfs_repo_history_file_json" 2> /dev/null)
    if [ -z "${changeset_owner_usernames_from_tfs_history[*]}" ]
    then

        debug "changeset_owner_usernames_from_tfs_history: "
        debug "${changeset_owner_usernames_from_tfs_history[@]}"

        error "Unable to get a list of unique authors' usernames from $tfs_repo_history_file_json"

    fi

    debug "changeset_owner_usernames_from_tfs_history: "
    debug "${changeset_owner_usernames_from_tfs_history[@]}"

    # Iterate through the list of owners from the TFS repo history file
    for changeset_owner_to_map_from_tfs_history in "${changeset_owner_usernames_from_tfs_history[@]}"
    do

        # Use jq to search the $author_name_mapping_file for the author's email address from the TFS repo history file
        author=$(jq -r '.["'"${changeset_owner_to_map_from_tfs_history//\\/\\\\}"'"]' "$author_name_mapping_file")

        # If jq didn't find the changeset owner from the $tfs_repo_history_file_json in the $author_name_mapping_file
        if [ -z "$author" ] || [ "$author" == "null" ]
        then

            debug "Author missing from mapping file: $changeset_owner_to_map_from_tfs_history"

            # Add the author to the list of missing authors
            missing_authors+=("$changeset_owner_to_map_from_tfs_history")

        else

            debug "Mapping author: $author"

            # Store the author in the associative array
            author_mapping_array["${changeset_owner_to_map_from_tfs_history}"]="${author}"

        fi

    # Read the next line from the changeset_owner_usernames_from_tfs_history list
    # This line is the problem that splits usernames with spaces in them
    done

    # If the author name mapping file is missing authors, list them out for the user to add
    if [[ -n "${missing_authors[*]}" ]]
    then

        # Clear or create the missing authors file
        echo "{" > "$missing_authors_file"

        # Add the missing authors on their own line
        for missing_author in "${missing_authors[@]}"
        do

            echo "    \"$missing_author\": \"Firstname Lastname <email@domain.com>\"," >> "$missing_authors_file"

        done

        echo "}" >> "$missing_authors_file"

        error "The author mapping file at $author_name_mapping_file is missing changeset owners from the TFS history file; these authors have been written to $missing_authors_file for you"

    fi

    # Output the name mapping to the user for visual verification
    if [[ $log_level_config == "DEBUG" ]]
    then
        debug "Authors found in TFS repo history and read from $author_name_mapping_file:"
        for author_iterator in "${!author_mapping_array[@]}"
        do
            echo "$author_iterator -> ${author_mapping_array[$author_iterator]}"
        done
        echo ""
    fi

    if [[ -z "${author_mapping_array[*]}" ]]
    then

        error "Could not parse any authors from $author_name_mapping_file"

    fi

}


function convert_tfs_changesets_to_git_commits() {

    # If continue_from_changeset is set, then this isn't our first commit
    if [[ -n $continue_from_changeset ]]
    then
        first_commit=false
    else
        first_commit=true
    fi

    changesets_remaining=$count_of_changesets

    debug "tfs_changeset_id_array:"
    debug "${tfs_changeset_id_array[@]}"

    # Iterate through $tfs_changeset_id_array
    for current_changeset_id in "${tfs_changeset_id_array[@]}"
    do

        # Read changeset information from the JSON history file
        if ! current_changeset_info=$(jq -c '.history.changeset[] | select (.["@id"] == "'"$current_changeset_id"'") | [.["@owner"], .["@committer"], .["@date"], .comment]' "$tfs_repo_history_file_json")
        then

            error "Unable to get current_changeset_info from changeset $current_changeset_id in $tfs_repo_history_file_json"

        fi

        # Extract fields from the changeset info
        current_changeset_owner=$(      echo "$current_changeset_info" | jq -r '.[0]')
        # Could support separate authors and committers, but would have to double this through the author mapping
        # current_changeset_committer=$(  echo "$current_changeset_info" | jq -r '.[1]')
        current_changeset_date=$(       echo "$current_changeset_info" | jq -r '.[2]')
        current_changeset_message=$(    echo "$current_changeset_info" | jq -r '.[3]')

        # Get the author's name and email address in Git format
        git_author="${author_mapping_array["$current_changeset_owner"]}"

        debug "git_author: $git_author"

        # Validate (again) that the author is mapped
        if [ -z "$git_author" ]
        then
            error "TFS changeset $current_changeset_id owner \n$current_changeset_owner\n is not mapped in $author_name_mapping_file"
        fi

        # Decrement the number of changesets remaining
        ((changesets_remaining--))

        # Print commit details to the user to show progress
        info "Downloading changeset $current_changeset_id from TFS [$changesets_remaining remaining]:"
        info "Author:  $current_changeset_owner -> $git_author"
        info "Date:    $current_changeset_date"
        info "Message: $current_changeset_message"
        info "tf output: "

        # Sync the files in the changeset from TFS
        if $first_commit
        then

            # On first commit, force the tf get command
            if ! tf get . \
                -collection:"$tfs_server/$tfs_collection" \
                -workspace:"$tfs_workspace" \
                -version:"C$current_changeset_id" \
                -force \
                -recursive \
                -noprompt

            then
                error "Error while getting first commit. See tf output"
            fi
            first_commit=false

            # An argument error occurred:
            # The workspace could not be determined from any argument paths or the current working directory.
            # It seems like this script cannot be run from a cousin directory, must be run from a parent directory of the git_target_directory

        else

            # On subsequent commits, don't force the tf get command
            if ! tf get . \
                -collection:"$tfs_server/$tfs_collection" \
                -workspace:"$tfs_workspace" \
                -version:"C$current_changeset_id" \
                -recursive \
                -noprompt
            then
                error "Error while getting current commit. See tf output"
            fi

        fi

        # Extract the author name from the git_author string
        git_author_name="$(echo "$git_author" | cut -d '<' -f1)"
        # Extract the author email from the git_author string
        git_author_email="$(echo "$git_author" | cut -d '<' -f2)"
        # Remove the trailing > from the email
        git_author_email="${git_author_email//>/}"

        # Using environment variables for the dates, because Git doesn't allow setting half of these by CLI arg
        export GIT_AUTHOR_DATE="$current_changeset_date"
        export GIT_AUTHOR_EMAIL="$git_author_email"
        export GIT_AUTHOR_NAME="$git_author_name"
        export GIT_COMMITTER_DATE="$current_changeset_date"
        export GIT_COMMITTER_EMAIL="$git_author_email"
        export GIT_COMMITTER_NAME="$git_author_name"


        # Print the new working directory to show where this command is getting run from
        info "Committing changeset $current_changeset_id to git repo"
        info "git output:"

        # Stage files to commit
        if ! git add .
        then
            error "Error while staging files. See git output"
        fi

        # Commit files
        # nothing to commit, working tree clean # Also an error that need to consider
        if ! git commit \
            --all \
            --allow-empty \
            --message="[ADO-$current_changeset_id] $current_changeset_message"
        then
            error "Error while committing changes. See git output"
        fi

    done

}


function git_garbage_collection() {

    info "Running git garbage collection"

    git reflog expire --all --expire=now
    git gc --prune=now --aggressive

}


function git_push() {

    # If no git remote was provided, then skip pushing
    if [[ -z "$git_remote_url" ]]
    then

        debug "No git remote configured, skipping git push"
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

    # Set file paths and variable values
    set_file_paths_before_parsing_user_args
    parse_and_validate_user_args "$@"
    set_file_paths_after_parsing_user_args

    # Verify that all needed dependencies are installed and in $PATH
    check_dependencies

    # If this is a new repo, create it, otherwise grab the latest changeset ID number to continue from
    tfs_login
    create_migration_tfs_workspace
    create_or_update_repo

    # If the user provided the --repo-size arg, get the size of the repo, then exit
    if $get_repo_size_arg; then get_repo_size ;fi

    # Run the migration process
    get_tfs_repo_history
    convert_tfs_repo_history_file_from_xml_to_json
    map_tfs_owners_to_git_authors
    convert_tfs_changesets_to_git_commits
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
