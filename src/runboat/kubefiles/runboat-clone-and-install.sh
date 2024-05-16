#!/bin/bash

set -exo pipefail

# Remove initialization sentinel and data, in case we are reinitializing.
rm -fr /mnt/data/*

# Remove addons dir, in case we are reinitializing after a previously
# failed installation.
rm -fr $ADDONS_DIR


# Download the repository at git reference into $ADDONS_DIR.
# We use curl instead of git clone because the git clone method used more than 1GB RAM,
# which exceeded the default pod memory limit.
mkdir -p $ADDONS_DIR
cd $ADDONS_DIR
curl -sSL https://github.com/${RUNBOAT_GIT_REPO}/tarball/${RUNBOAT_GIT_REF} | tar zxf - --strip-components=1

cp test-requirements.txt spp-test-requirements.txt

# Download git dependencies to tmp folder
mkdir ~/git_temp
cd ~/git_temp
git clone https://github.com/OpenG2P/openg2p-registry.git --depth 1 --branch 17.0-develop
git clone https://github.com/OpenG2P/openg2p-program.git --depth 1 --branch 17.0-develop
# git clone https://github.com/OpenSPP/geospatial.git --depth 1 --branch 17.0-mig-base_geoengine
git clone https://github.com/muk-it/odoo-modules.git --depth 1 --branch 17.0
git clone https://github.com/OpenG2P/openg2p-security.git --depth 1 --branch 17.0-develop
git clone https://github.com/OpenG2P/openg2p-vci.git --depth 1 --branch 17.0-develop

rm -rf openg2p-program/*rest_api* openg2p-program/g2p_documents
rm -rf odoo-modules/muk_web_enterprise_theme
cp -r openg2p-registry/* ${ADDONS_DIR}/
cat ${ADDONS_DIR}/test-requirements.txt >> ${ADDONS_DIR}/spp-test-requirements.txt
cp -r openg2p-program/* ${ADDONS_DIR}/
cat ${ADDONS_DIR}/test-requirements.txt >> ${ADDONS_DIR}/spp-test-requirements.txt
cp -r openg2p-security/* ${ADDONS_DIR}/
cat ${ADDONS_DIR}/test-requirements.txt >> ${ADDONS_DIR}/spp-test-requirements.txt
cp -r openg2p-vci/* ${ADDONS_DIR}/
cat ${ADDONS_DIR}/test-requirements.txt >> ${ADDONS_DIR}/spp-test-requirements.txt
# cp -r geospatial/* ${ADDONS_DIR}/
# cat ${ADDONS_DIR}/test-requirements.txt >> ${ADDONS_DIR}/spp-test-requirements.txt
# MUK addons
cp -r odoo-modules/* ${ADDONS_DIR}/
echo "git+https://github.com/OpenG2P/openg2p-program@17.0-develop#subdirectory=g2p_programs" >> ${ADDONS_DIR}/spp-test-requirements.txt
echo "odoo-test-helper" >> ${ADDONS_DIR}/spp-test-requirements.txt

export EXCLUDE_REGEX="odoo-addon-g2p.*|odoo-addon-muk.*"
export SKIP_EXT_DEB_DEPENDENCIES="true"
cd -
cp spp-test-requirements.txt test-requirements.txt

# Removing spp_pos as it has not been updated to Odoo 17
rm -rf spp_pos
# Installing specific Debian packages to be able to pip install pyjq
apt update
apt install -y autoconf automake libtool libtool-bin bison flex

# Install.
INSTALL_METHOD=${INSTALL_METHOD:-oca_install_addons}
if [[ "${INSTALL_METHOD}" == "oca_install_addons" ]] ; then
    oca_install_addons
elif [[ "${INSTALL_METHOD}" == "editable_pip_install" ]] ; then
    pip install -e .
else
    echo "Unsupported INSTALL_METHOD: '${INSTALL_METHOD}'"
    exit 1
fi

# Keep a copy of the venv that we can re-use for shorter startup time.
cp -ar /opt/odoo-venv/ /mnt/data/odoo-venv

touch /mnt/data/initialized
