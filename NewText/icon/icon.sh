#!/bin/sh
# for Mac OS X
# required sips command

cd `dirname $0`

outdir="icon.iconset"
mkdir -p $outdir

if [ -e "icon_512x512@2x.png" ]; then
	BASE_FILE="icon_512x512@2x.png"
else
	echo "Not Found file icon_512x512@2x.png..."
	exit 1
fi

sips -Z 1024 ${BASE_FILE} --out ${outdir}/icon_512x512@2x.png
sips -Z 512 ${BASE_FILE} --out ${outdir}/icon_512x512.png
sips -Z 512 ${BASE_FILE} --out ${outdir}/icon_256x256@2x.png
sips -Z 256 ${BASE_FILE} --out ${outdir}/icon_256x256.png
sips -Z 256 ${BASE_FILE} --out ${outdir}/icon_128x128@2x.png
sips -Z 128 ${BASE_FILE} --out ${outdir}/icon_128x128.png
sips -Z 64 ${BASE_FILE} --out ${outdir}/icon_32x32@2x.png
sips -Z 32 ${BASE_FILE} --out ${outdir}/icon_32x32.png
sips -Z 32 ${BASE_FILE} --out ${outdir}/icon_16x16@2x.png
sips -Z 16 ${BASE_FILE} --out ${outdir}/icon_16x16.png

iconutil -c icns ${outdir}

exit 0
