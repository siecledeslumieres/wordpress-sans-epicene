#!/bin/bash

# Get the path of this script
script_dir="$(dirname "$(realpath "$0")")"

# Define the working mode of the script
#  --standalone
#    Modify all translation files directly into their directory.
#    Can be used in a cron task to automatically fix the translations
#  --plugin_feeder
#    Do not modify the translations. Build only mo and po files for the plugin wordpress-sans-epicene
mode=$1

if [ -z "$mode" ] || [ "$mode" != "--standalone" ] && [ "$mode" != "--plugin_feeder" ]
then
    echo "Please choose a mode between --standalone and --plugin_feeder for the script."
    echo "The mode has to be set as an argument for the script."
    exit 1
fi

# languages_dir=/var/www/wordpress/wp-content/languages
languages_dir="$script_dir/Original"
dest_dir="$script_dir/modified_translations"
witness_dir="$script_dir/witnesses"
git_repo=https://github.com/Zeldemir/wordpress-sans-epicene
# Mail recipient. root should be enough if you read the mails for this server
recipient=root

mkdir -p "$dest_dir"
mkdir -p "$witness_dir"

# List of string to fix
# The format is as following:
# >string to find<::>string to replace with<
cleaning_strings="
# auteur/autrice
>/autrices?<::><
# auteurs ou autrices
# Auteur ou autrice
> ou autrices?<::><
# de l’auteur ou de l’autrice
> ou de l’autrice<::><
# l’auteur ou l’autrice
> ou l’autrice<::><
# d’auteur ou d’autrice
> ou d’autrice<::><
# un auteur ou une autrice
> ou une autrice<::><

# administrateurs/administratrices
# administrateur/administratrice
>/administratrices?<::><
# administrateurs ou administratrices
# administrateur ou administratrice
> ou administratrices?<::><
# l’administrateur ou l’administratrice
> ou l’administratrice<::><
# l’administrateur ou de l’administratrice
> ou de l’administratrice<::><
# l’administrateur ou à l’administratrice
> ou à l’administratrice<::><
# les administrateurs et les administratrices
> et les administratrices<::><
# un administrateur ou une administratrice
> ou une administratrice<::><
# administrateur, administratrice
>, administratrice<::><

# une développeuse ou un développeur
>une développeuse ou <::><
# les développeurs et les développeuses
> et les développeuses<::><

# éditeur/éditrice
>/éditrices?<::><
# éditeurs ou éditrices
> ou éditrices?<::><

# contributeur/contributrice
>/contributrices?<::><
# Contributrices & contributeurs
>Contributrices & c<::>C<

# Traductrices & traducteurs
>Traductrices & t<::>T<

# utilisateur/utilisatrice
>/utilisatrices?<::><
# utilisateur ou utilisatrice
> ou utilisatrice<::><
# l’utilisateur ou l’utilisatrice
> ou l’utilisatrice<::><
# l’utilisateur ou à l’utilisatrice
> ou à l’utilisatrice<::><
# l’utilisateur ou de l’utilisatrice
> ou de l’utilisatrice<::><
# l’utilisateur et l’utilisatrice
> et l’utilisatrice<::><
# Utilisateurs et utilisatrices
> et utilisatrices<::><

# du commentateur ou de la commentatrice
> ou de la commentatrice<::><

# abonné/abonnée
>/abonnées?<::><

# connecté·e
# déconnecté·e
# notifié·e
# reconnecté·e
# invité·e
# rencontré·e
>é·e<::>é<
# certain·e
# prêt·e
# petit·e ami·e
>·e<::><
"

cleaner () {
    local line="$1"
    local pattern_to_find="$2"
    local replacement="$3"
    echo "$line" | sed --quiet --regexp-extended "s@$pattern_to_find@$replacement@gp"
}

seek_and_destroy () {
    local line="$1"

    # Check the line against the quick search string to find if there's anything to remove in that line
    if echo "$line" | grep --extended-regexp --quiet "$quick_search"
    then
        # Then find what is to be cleaned in that line
        for i in $(seq 0 $(( ${#cleaning_array_seek[@]} - 1)) )
        do
            if echo "$line" | grep --extended-regexp --quiet "${cleaning_array_seek[$i]}"
            then
                # Clean the first inclusive term found and return the modified line
                cleaner "$line" "${cleaning_array_seek[$i]}" "${cleaning_array_destroy[$i]}"
                break
            fi
        done
    fi
}


# Build the list of file to modify
if [ "$mode" == "--standalone" ]
then
    # In standalone mode, work on all po and mo translation files.
    IFS_backup=$IFS; IFS=$'\n'
    files_list=( $(find "$languages_dir" -print | grep ".po$") )
    IFS=$IFS_backup
else
    files_list=("$languages_dir/admin-fr_FR.po" "$languages_dir/admin-network-fr_FR.po" "$languages_dir/fr_FR.po")
fi

# Check if there's anything new in the translation files

# Make a checksum of each file in the list, then a checksum of all these cheksums.
# That give us a checksum for all the files at once
current_checksum=$(find "${files_list[@]}" -exec md5sum {} \; | md5sum | cut -d' ' -f1)
if [ "$mode" == "--standalone" ]
then
    checksum_file="$script_dir/checksum_standalone"
else
    checksum_file="$script_dir/checksum_plugin_feeder"
fi
last_checksum=$(cat "$checksum_file" 2> /dev/null )

if [ "$current_checksum" == "$last_checksum" ]
then
    echo "Nothing to do, the checksum is the same."
    # No new files to process
    exit 0
fi

# Store the new checksum for the next execution.
echo "$current_checksum" > "$checksum_file"


# Compile the cleaning strings for better performances
# Remove comments
cleaning_strings="$(echo "$cleaning_strings" | sed --regexp-extended "/^#/d")"
# And empty lines
cleaning_strings="$(echo "$cleaning_strings" | sed --regexp-extended "/^$/d")"
# We use 2 arrays
declare -a cleaning_array_seek
declare -a cleaning_array_destroy
quick_search=""
while read values
do
    # Keep only the value before the marker <::>
    seek="${values%%<::>*}"
    seek="${seek#>}"
    # And the value after
    destroy="${values##*<::>}"
    # Then remove the ending marker <
    destroy="${destroy%<}"

    # Put in each array the string to find and the string to replace with
    cleaning_array_seek+=( "$seek" )
    cleaning_array_destroy+=( "$destroy" )
    # And build a quick search string to quickly find culprit lines
    quick_search+="$seek|"
done <<< "$(echo "$cleaning_strings")"

# Remove the ending |
quick_search="${quick_search%|}"

> diff_result

# Read each file to clean them
for file in "${files_list[@]}"
do

    # standalone mode
    if [ "$mode" == "--standalone" ]
    then
        echo "Working on file $file..."

        final_translation_file="$file"
        witness_file="$witness_dir/$(basename "$file").wit"

        cp "$final_translation_file" "$witness_file"

    # plugin_feeder mode
    else
        echo "Working on file $file..."

        final_translation_file="$dest_dir/$(basename "$file")"
        witness_file="$witness_dir/$(basename "$file").wit"

        > "$final_translation_file"
        > "$witness_file"

        translation_string=0
        # Read each line of the file
        while read -r line
        do
            # Purge variable before starting a new translation string
            #   And write down strings
            # A blank line indicate the end of a translation string
            if [ -z "$line" ]
            then
                if [ -n "$msgstr" ]
                then
                    echo "$msgid" >> "$final_translation_file"
                    echo "$msgstr" >> "$final_translation_file"
                    echo "" >> "$final_translation_file"

                    # Duplicate in a witness file for a final diff
                    echo "$msgid" >> "$witness_file"
                    echo "$original_msgstr" >> "$witness_file"
                    echo "" >> "$witness_file"
                fi
                msgid=""
                msgstr=""
                original_msgstr=""
            fi

            # Look for msgctxt or msgid as beginning of a translation string.
            if echo "$line" | grep --quiet --extended-regexp "^msgctxt|^msgid"
            then
                # If there's already a line stored in the variable, add a new line
                if [ -n "$msgid" ]; then
                    msgid+="
"
                fi
                # Store the msgid and msgctxt.
                msgid+="$line"
            fi

            if echo "$line" | grep --quiet --extended-regexp "^msgstr"
            then
                # Check the line to remove inclusive writings
                cleaned_line="$(seek_and_destroy "$line")"
                if [ -n "$cleaned_line" ]
                then
                    # If there's already a line stored in the variable, add a new line
                    if [ -n "$msgstr" ]; then
                        msgstr+="
"
                        original_msgstr+="
"
                    fi
                    msgstr+="$cleaned_line"
                    original_msgstr+="$line"
                    echo -n "."
                fi
            fi
        done < "$file"
    fi

    # Clean again the whole file to remove other inclusive writings on string already cleaned.
    for i in $(seq 0 $(( ${#cleaning_array_seek[@]} - 1)) )
    do
        sed --in-place --regexp-extended "s@${cleaning_array_seek[$i]}@${cleaning_array_destroy[$i]}@g" "$final_translation_file"
    done

    echo " File $file is done."

    # Créer un diff du fichier modifié par rapport à la version originale
    git --no-pager diff --unified=0 --word-diff=color --no-index "$witness_file" "$final_translation_file" >> diff_result

    # Compile the .mo file from the .po
    compiled_mo_file="$(dirname "$final_translation_file")/$(basename --suffix=.po "$final_translation_file").mo"
    msgfmt --output-file="$compiled_mo_file" "$final_translation_file"
done

# Print the diff to check the modifications made by the script
cat diff_result

# Make a commit on the repo to update the plugin
if [ "$mode" == "--plugin_feeder" ]
then

    if [ ! -e "$script_dir/ssh_key" ]
    then
        ssh-keygen -t rsa -f "$script_dir/ssh_key" -P ''
        echo -e "\nIn order for the script to work automatically,"
        echo "please add the public key to the 'Deploy keys'"
        echo "into the Settings of the repository."
        echo "Public key to add:"
        cat "$script_dir/ssh_key.pub"
        rm -f "$script_dir/checksum_plugin_feeder"
        exit 0
    fi

    # Clone the distant repository
    if [ ! -e "$script_dir/git_repository" ]
    then
        git clone $git_repo "$script_dir/git_repository"

        (
            cd "$script_dir/git_repository"
            # Move from the http address to a ssh address
            git remote set-url origin ${git_repo/https:\/\/github.com\//git@github.com:}.git
        )
    fi

    pushd "$script_dir/git_repository"

    # Configure git to use ssh
    git config core.sshCommand "ssh -i \"$script_dir/ssh_key\" -F /dev/null"
    # Delete the working branch
    git checkout main
    git branch -D translation_update
    git push origin --delete translation_update

    # Update the repo
    git pull

    # Recreate a branch from main
    git checkout -b translation_update

    # Update the files in the working branch
    while read file
    do
        cp "$file" "$script_dir/git_repository"
    done <<< "$(find "$dest_dir" -print)"

    # Feed the mail
    echo -e "Bonjour\n" > "$script_dir/mail_content"
    echo "De nouvelles traductions sont disponibles pour l'extension wordpress-sans-epicene." >> "$script_dir/mail_content"
    echo "Un commit devrait avoir été fait sur le dépôt $git_repo sur la branche translation_update" >> "$script_dir/mail_content"
    echo -e "\nCe commit contient les modifications suivantes:" >> "$script_dir/mail_content"

    # Commit the changes
    git add --all
    git status -v >> "$script_dir/mail_content"
    git commit -m "Update translations"
    git push -u origin translation_update

    popd

    # Send un mail to inform that a new commit is done.
    mail -s "[Wordpress sans épicène] Nouvelles traductions à ajouter à l'extension" "$recipient" < "$script_dir/mail_content"
fi
