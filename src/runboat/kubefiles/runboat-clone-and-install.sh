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

echo "without_demo = all" >> /etc/odoo.cfg
cat /etc/odoo.cfg

cp test-requirements.txt spp-test-requirements.txt

# Remove OpenG2P stubs from openspp-modules
rm -rf g2p_bank
rm -rf g2p_bank_rest_api
rm -rf g2p_encryption
rm -rf g2p_encryption_keymanager
rm -rf g2p_encyption_rest_api
rm -rf g2p_entitlement_cash
rm -rf g2p_enumerator
rm -rf g2p_openid_vci
rm -rf g2p_openid_vci_rest_api
rm -rf g2p_programs
rm -rf g2p_registry_base
rm -rf g2p_registry_documents
rm -rf g2p_registry_encryption
rm -rf g2p_registry_group
rm -rf g2p_registry_individual
rm -rf g2p_registry_membership
rm -rf g2p_registry_rest_api
rm -rf muk_web_appsbar
rm -rf muk_web_chatter
rm -rf muk_web_colors
rm -rf muk_web_dialog
rm -rf muk_web_theme

# Download git dependencies to tmp folder
mkdir ~/git_temp
cd ~/git_temp
git clone https://github.com/OpenSPP/openg2p-registry.git --depth 1 --branch 17.0-develop-openspp
git clone https://github.com/OpenSPP/openg2p-program.git --depth 1 --branch 17.0-develop-openspp
git clone https://github.com/OpenSPP/mukit-modules.git --depth 1 --branch 17.0-openspp
rm -rf openg2p-registry/*/tests
rm -rf openg2p-registry/g2p_documents
rm -rf openg2p-registry/g2p_encryption_keymanager
rm -rf openg2p-registry/g2p_odk_importer
rm -rf openg2p-registry/g2p_odk_user_mapping
rm -rf openg2p-registry/g2p_profile_image
rm -rf openg2p-registry/g2p_registry_documents
rm -rf openg2p-registry/g2p_registry_encryption
rm -rf openg2p-program/*/tests
rm -rf openg2p-program/g2p_entitlement_voucher
rm -rf openg2p-program/g2p_odk_importer_program
rm -rf openg2p-program/g2p_formio
rm -rf openg2p-program/g2p_notifications_voucher
rm -rf openg2p-program/g2p_payment_cash
rm -rf openg2p-program/g2p_payment_files
rm -rf openg2p-program/g2p_payment_g2p_connect
rm -rf openg2p-program/g2p_program_documents
rm -rf mukit-modules/muk_web_enterprise_theme
cp -r openg2p-registry/* ${ADDONS_DIR}/
cat ${ADDONS_DIR}/test-requirements.txt >> ${ADDONS_DIR}/spp-test-requirements.txt
cp -r openg2p-program/* ${ADDONS_DIR}/
# Do not install test requirements for openg2p-program as they are only references
# to OpenSPP components from openspp-modules and installing them will overwrite the
# module versions from the branch curl:ed on line 18.
# cat ${ADDONS_DIR}/test-requirements.txt >> ${ADDONS_DIR}/spp-test-requirements.txt

# MUK addons
cp -r mukit-modules/* ${ADDONS_DIR}/
echo "git+https://github.com/OpenSPP/openg2p-program@17.0-develop-openspp#subdirectory=g2p_programs" >> ${ADDONS_DIR}/spp-test-requirements.txt
# wecho "git+https://github.com/OpenSPP/openg2p-rest-framework@17.0#subdirectory=fastapi" >> ${ADDONS_DIR}/spp-test-requirements.txt
echo "git+https://github.com/OpenSPP/openg2p-rest-framework@17.0#subdirectory=extendable" >> ${ADDONS_DIR}/spp-test-requirements.txt
echo "git+https://github.com/OpenSPP/openg2p-rest-framework@17.0#subdirectory=extendable_fastapi" >> ${ADDONS_DIR}/spp-test-requirements.txt
echo "odoo-test-helper" >> ${ADDONS_DIR}/spp-test-requirements.txt

export EXCLUDE_REGEX="odoo-addon-g2p.*|odoo-addon-muk.*"
export SKIP_EXT_DEB_DEPENDENCIES="true"
cd -
cp spp-test-requirements.txt test-requirements.txt

# Removing spp_pos as it has not been updated to Odoo 17
rm -rf spp_pos

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
