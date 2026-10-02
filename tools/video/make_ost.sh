#!/usr/bin/env bash
# Los vídeos de presentación de la banda sonora (ver tools/video/ost/main.lua).
#   tools/video/make_ost.sh [megacrabby megacrabby_ice megagloomy]   (sin argumentos: los tres)
cd "$(dirname "$0")/../.." || exit 1
for b in ${@:-megacrabby megacrabby_ice megagloomy}; do
    love tools/video/ost "$b" || exit 1
done
