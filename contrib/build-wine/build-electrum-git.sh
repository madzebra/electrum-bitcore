#!/bin/bash

NAME_ROOT=electrum-bitcore
PYTHON_VERSION=3.5.4

# These settings probably don't need any change
export WINEPREFIX=/opt/wine64
export PYTHONDONTWRITEBYTECODE=1
export PYTHONHASHSEED=22

PYHOME=c:/python$PYTHON_VERSION
PYTHON="wine $PYHOME/python.exe -OO -B"

if [ ! -d $WINEPREFIX/drive_c/MinGW ]; then
wine mingw-get-setup.exe
fi

# Let's begin!
cd `dirname $0`
set -e

if [ ! -d tmp ]; then
mkdir tmp
fi
cd tmp

if [ -d electrum-bitcore ]; then
    cd electrum-bitcore
    git pull
    git checkout
    cd ..
else
    URL=https://github.com/LIMXTEC/electrum-bitcore.git
    git clone $URL electrum-bitcore
fi
if [ -d electrum-bitcore-icons ]; then
    cd electrum-bitcore-icons
    git pull
    git checkout master
    cd ..
else
    URL=https://github.com/ULorenzen/electrum-bitcore-icons.git
    git clone -b master $URL electrum-bitcore-icons
fi
if [ -d electrum-locale ]; then
    cd electrum-locale
    git pull
    git checkout master
    cd ..
else
    URL=https://github.com/ULorenzen/electrum-bitcore-locale.git
    git clone -b master $URL electrum-locale
fi

pushd electrum-locale
for i in ./locale/*; do
    dir=$i/LC_MESSAGES
    mkdir -p $dir
    msgfmt --output-file=$dir/electrum.mo $i/electrum.po || true
done
popd

pushd electrum-bitcore
if [ ! -z "$1" ]; then
    git checkout $1
fi

VERSION=`grep ELECTRUM_VERSION lib/version.py | sed "s/.*= '\(.*\)'.*/\1/"`
echo "Last commit: $VERSION"
find -exec touch -d '2000-11-11T11:11:11+00:00' {} +
popd

rm -rf $WINEPREFIX/drive_c/electrum
cp -r electrum-bitcore $WINEPREFIX/drive_c/electrum
cp electrum-bitcore/LICENCE .
cp -r electrum-locale/locale $WINEPREFIX/drive_c/electrum/lib/
cp electrum-bitcore-icons/icons_rc.py $WINEPREFIX/drive_c/electrum/gui/qt/

# Install frozen dependencies
$PYTHON -m pip install -r ../../deterministic-build/requirements.txt

$PYTHON -m pip install -r ../../deterministic-build/requirements-hw.txt

# fixes to get the MinGW compiler to run with Python
sed -i "/btxcext\/inc/ a \                 extra_compile_args = ['-D_hypot=hypot']," $WINEPREFIX/drive_c/electrum/setup.py
cp ../vcruntime140.lib $WINEPREFIX/drive_c/python$PYTHON_VERSION/libs
cp $WINEPREFIX/drive_c/python$PYTHON_VERSION/Lib/distutils/cygwinccompiler.py cygwinccompiler.py
sed -i "/return \['msvcr100'\]/ a \        elif msc_ver == '1900':\n            return \['vcruntime140'\]" $WINEPREFIX/drive_c/python$PYTHON_VERSION/Lib/distutils/cygwinccompiler.py

pushd $WINEPREFIX/drive_c/electrum
WINEPATH="C:\\MinGW\\bin;C:\\MinGW\\msys\\1.0\\bin" $PYTHON setup.py build_ext -c mingw32
$PYTHON setup.py install
popd

cp cygwinccompiler.py $WINEPREFIX/drive_c/python$PYTHON_VERSION/Lib/distutils/cygwinccompiler.py 
cd ..

rm -rf dist/

# build standalone and portable versions
wine "C:/python$PYTHON_VERSION/scripts/pyinstaller.exe" --noconfirm --ascii --name $NAME_ROOT-$VERSION -w deterministic.spec

# set timestamps in dist, in order to make the installer reproducible
pushd dist
find -exec touch -d '2000-11-11T11:11:11+00:00' {} +
popd

# build NSIS installer
# $VERSION could be passed to the electrum.nsi script, but this would require some rewriting in the script itself.
wine "$WINEPREFIX/drive_c/Program Files/NSIS/makensis.exe" /DPRODUCT_VERSION=$VERSION electrum.nsi

cd dist
mv electrum-bitcore-setup.exe $NAME_ROOT-$VERSION-setup.exe
cd ..

echo "Done."
md5sum dist/electrum*exe
