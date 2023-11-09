#!/bin/bash

app_base="FinderZIP"
for theme in light dark; do
  app="${app_base}_${theme}.app"
  cp -R ${app_base}.app ${app}
  cp icons/icon_${theme}.icns ${app}/Contents/Resources/ApplicationStub.icns
done

