#!/bin/bash
cd "/Users/firdavsiynazaraliev/Documents/Claude projects/gamepass-uz/flutter_app/build/web"
exec ruby -run -e httpd . -p "${PORT:-8081}"
