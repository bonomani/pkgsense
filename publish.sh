#!/bin/bash
# Publie manuellement le contenu de test/repo/ vers la branche gh-pages

set -e

BRANCH=gh-pages
TMP_DIR=$(mktemp -d)

echo "🔄 Clonage de la branche $BRANCH..."
git clone --depth 1 --branch $BRANCH git@github.com:bonomani/pkgsense.git $TMP_DIR

echo "📦 Copie des fichiers générés..."
cp test/repo/* $TMP_DIR/
touch $TMP_DIR/.nojekyll

cd $TMP_DIR
git add .
git commit -m "🔄 Publication manuelle du paquet test" || echo "✅ Aucun changement à publier"
git push origin $BRANCH

echo "✅ Publication terminée"

