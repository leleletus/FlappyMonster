#!/usr/bin/env bash
# Los vídeos de presentación de la banda sonora (ver tools/video/ost/main.lua): un vídeo por tema de jefe.
#   tools/video/make_ost.sh [megagummy megacrabby miniboss1 snowboss megacrabby_ice megagloomy mirror]   (sin argumentos: todos)
cd "$(dirname "$0")/../.." || exit 1
for b in ${@:-megagummy megacrabby miniboss1 snowboss megacrabby_ice megagloomy mirror}; do
    love tools/video/ost "$b" || exit 1
done
