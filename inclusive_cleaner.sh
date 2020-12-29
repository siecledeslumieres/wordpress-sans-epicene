#!/bin/bash

cleaner () {
    sed --in-place --regexp-extended "s@$1@$2@g" "$3"
}

files_list=("admin-fr_FR.mo" "admin-fr_FR.po" "admin-network-fr_FR.mo" "admin-network-fr_FR.po" "fr_FR.mo" "fr_FR.po")

for file in "${files_list[@]}"
do
echo "> Working on file $file"
    # auteur/autrice
    cleaner "/autrices?" "" "$file"
    # auteurs ou autrices
    # Auteur ou autrice
    cleaner " ou autrices?" "" "$file"
    # de l’auteur ou de l’autrice
    cleaner " ou de l’autrice" "" "$file"
    # l’auteur ou l’autrice
    cleaner " ou l’autrice" "" "$file"
    # l’auteur ou autrice
    cleaner " ou autrice" "" "$file"
    # d’auteur ou d’autrice
    cleaner " ou d’autrice" "" "$file"
    # un auteur ou une autrice
    cleaner " ou une autrice" "" "$file"

    # administrateurs/administratrices
    # administrateur/administratrice
    cleaner "/administratrices?" "" "$file"
    # administrateurs ou administratrices
    # administrateur ou administratrice
    cleaner " ou administratrices?" "" "$file"
    # l’administrateur ou l’administratrice
    cleaner " ou l’administratrice" "" "$file"
    # l’administrateur ou de l’administratrice
    cleaner " ou de l’administratrice" "" "$file"
    # l’administrateur ou à l’administratrice
    cleaner " ou à l’administratrice" "" "$file"
    # les administrateurs et les administratrices
    cleaner " et les administratrices" "" "$file"
    # un administrateur ou une administratrice
    cleaner " ou une administratrice" "" "$file"
    # administrateur, administratrice
    cleaner ", administratrice" "" "$file"

    # une développeuse ou un développeur
    cleaner "une développeuse ou " "" "$file"
    # les développeurs et les développeuses
    cleaner " et les développeuses" "" "$file"

    # éditeur/éditrice
    cleaner "/éditrices?" "" "$file"
    # éditeurs ou éditrices
    cleaner " ou éditrices?" "" "$file"

    # contributeur/contributrice
    cleaner "/contributrices?" "" "$file"
    # Contributrices & contributeurs
    cleaner "Contributrices & c" "C" "$file"

    # Traductrices & traducteurs
    cleaner "Traductrices & t" "T" "$file"

    # utilisateur/utilisatrice
    cleaner "/utilisatrices?" "" "$file"
    # utilisateur ou utilisatrice
    cleaner " ou utilisatrice" "" "$file"
    # l’utilisateur ou l’utilisatrice
    cleaner " ou l’utilisatrice" "" "$file"
    # l’utilisateur ou à l’utilisatrice
    cleaner " ou à l’utilisatrice" "" "$file"
    # l’utilisateur ou de l’utilisatrice
    cleaner " ou de l’utilisatrice" "" "$file"
    # l’utilisateur et l’utilisatrice
    cleaner " et l’utilisatrice" "" "$file"
    # Utilisateurs et utilisatrices
    cleaner " et utilisatrices" "" "$file"

    # du commentateur ou de la commentatrice
    cleaner " ou de la commentatrice" "" "$file"

    # abonné/abonnée
    cleaner "/abonnées?" "" "$file"

    # connecté·e
    # déconnecté·e
    # notifié·e
    # reconnecté·e
    # invité·e
    # rencontré·e
    cleaner "é·e" "é" "$file"
    # certain·e
    # prêt·e
    # petit·e ami·e
    cleaner "·e" "" "$file"
done
