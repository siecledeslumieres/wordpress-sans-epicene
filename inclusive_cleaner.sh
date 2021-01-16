#!/bin/bash

# Get the path of this script
script_dir="$(dirname "$(realpath "$0")")"

# languages_dir=/var/www/wordpress/wp-content/languages
languages_dir="$script_dir/Original"
dest_dir="$script_dir/modified_translations"

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

files_list=("$languages_dir/admin-fr_FR" "$languages_dir/admin-network-fr_FR" "$languages_dir/fr_FR")

# Read each file to clean them
for file in "${files_list[@]}"
do

    echo "Working on file $file.po..."

    final_translation_file="$dest_dir/$(basename "$file").po"
    witness_file="$script_dir/$(basename "$file").po.wit"

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
    done < "$file.po"

    # Clean again the whole file to remove other inclusive writings on string already cleaned.
    for i in $(seq 0 $(( ${#cleaning_array_seek[@]} - 1)) )
    do
        sed --in-place --regexp-extended "s@${cleaning_array_seek[$i]}@${cleaning_array_destroy[$i]}@g" "$final_translation_file"
    done

    echo " File $file.po is done."

    # Créer un diff du fichier modifié par rapport à la version originale
    git --no-pager diff --unified=0 --word-diff=color --no-index "$witness_file" "$final_translation_file" >> diff_result

    # Compile the .mo file from the .po
    compiled_mo_file="$(dirname "$final_translation_file")/$(basename --suffix=.po "$final_translation_file").mo"
    msgfmt --output-file="$compiled_mo_file" "$final_translation_file"
done

# Print the diff to check the modifications made by the script
cat diff_result
