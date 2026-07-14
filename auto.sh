#!/bin/bash

# =============================================
#  WHM Server Setup Script v1.0
#  Supported: RHEL Family Only
# =============================================

# --------------------------------------------
#  HELPER: Non-critical (warn & continue)
# --------------------------------------------
run_cmd() {
    local task=$1
    shift
    echo ""
    echo "========================================"
    echo "  $task"
    echo "========================================"
    "$@" || echo "[WARNING] '$task' failed, continuing..."
}

# --------------------------------------------
#  HELPER: Critical (pause on error)
# --------------------------------------------
run_cmd_strict() {
    local task=$1
    shift
    echo ""
    echo "========================================"
    echo "  $task"
    echo "========================================"
    "$@"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo ""
        echo "[ERROR] '$task' failed (exit code: $exit_code)."
        echo "========================================"
        echo "  Press R to Retry | C to Continue | E to Exit"
        echo "========================================"
        while true; do
            read -p "  Your choice [R/C/E] : " choice
            case "$choice" in
                R|r)
                    echo "  Retrying..."
                    "$@"
                    if [ $? -ne 0 ]; then
                        echo "[ERROR] Retry also failed. Please fix manually."
                    else
                        echo "[OK] Retry successful!"
                        break
                    fi
                    ;;
                C|c)
                    echo "  Skipping and continuing to next step..."
                    break
                    ;;
                E|e)
                    echo "  Exiting. You are still inside screen session."
                    exec bash
                    ;;
                *)
                    echo "  Invalid choice. Press R, C or E."
                    ;;
            esac
        done
    fi
}

# =============================================
#  INSIDE SCREEN — Full Installation
# =============================================
main_setup() {

    # --------------------------------------------
    #  STEP 0 — System Update & Tools
    # --------------------------------------------
    echo ""
    echo "========================================"
    echo "  Updating System..."
    echo "========================================"
    dnf update -y

    echo ""
    echo "========================================"
    echo "  Installing Required Tools..."
    echo "========================================"
    dnf install -y --skip-broken curl wget tar \
        perl-libwww-perl perl-LWP-Protocol-https perl-Time-HiRes \
        perl-IO-Socket-INET6 perl-Net-SSLeay perl-IO-Socket-SSL

    # --------------------------------------------
    #  Validate cPanel Version & Set cpupdate.conf
    # --------------------------------------------
    if [[ -z "$CPANEL_VERSION" ]]; then
        echo ""
        echo "  cPanel Version : not provided — installing latest"
        echo "[OK] Skipping cpupdate.conf — latest will be installed"
    else
        VALID_VERSIONS=("11.126" "11.130" "11.132" "11.134" "11.136" "release")
        VERSION_VALID=0
        for V in "${VALID_VERSIONS[@]}"; do
            if [[ "$CPANEL_VERSION" == ${V}* ]]; then
                VERSION_VALID=1
                break
            fi
        done

        if [ $VERSION_VALID -eq 0 ]; then
            echo ""
            echo "[ERROR] '$CPANEL_VERSION' is not a valid cPanel version."
            echo "  Valid versions start with: ${VALID_VERSIONS[*]}"
            echo "  Please re-run the script with a correct version."
            exec bash
        fi

        echo ""
        echo "========================================"
        echo "  Setting cPanel Version in cpupdate.conf"
        echo "========================================"
        echo "CPANEL=$CPANEL_VERSION" > /etc/cpupdate.conf
        echo "[OK] /etc/cpupdate.conf set to CPANEL=$CPANEL_VERSION"
    fi

    # --------------------------------------------
    #  STEP 1 — WHM Install
    # --------------------------------------------
    echo ""
    echo "========================================"
    echo "  [1/5] WHM / cPanel Installation"
    echo "========================================"

    run_cmd_strict "Downloading WHM/cPanel Installer..." \
        bash -c 'cd /home && curl -o latest -L https://securedownloads.cpanel.net/latest'

    run_cmd_strict "Installing WHM/cPanel..." \
        bash -c 'cd /home && sh latest'

    run_cmd_strict "Restarting NetworkManager..." \
        systemctl restart NetworkManager

    run_cmd_strict "Enabling NetworkManager..." \
        systemctl enable --now NetworkManager

    echo ""
    echo "========================================"
    echo "  NetworkManager Status"
    echo "========================================"
    systemctl status NetworkManager --no-pager

    # --------------------------------------------
    #  STEP 3 — CSF Firewall
    # --------------------------------------------
    echo ""
    echo "========================================"
    echo "  [2/5] CSF Firewall Setup"
    echo "========================================"

    run_cmd_strict "Installing CSF Firewall..." \
        dnf install -y cpanel-csf

    run_cmd_strict "Setting TESTING=0..." \
        sed -i 's/^TESTING = .*/TESTING = "0"/' /etc/csf/csf.conf

    run_cmd_strict "Setting RESTRICT_SYSLOG=3..." \
        sed -i 's/^RESTRICT_SYSLOG = .*/RESTRICT_SYSLOG = "3"/' /etc/csf/csf.conf

    echo ""
    echo "  Verifying CSF config..."
    grep -E '^TESTING|^RESTRICT_SYSLOG' /etc/csf/csf.conf

    run_cmd_strict "Restarting CSF..."   csf -r
    run_cmd_strict "Enabling CSF..."     systemctl enable csf
    run_cmd_strict "Enabling LFD..."     systemctl enable lfd
    run_cmd_strict "Restarting CSF..."   systemctl restart csf
    run_cmd_strict "Restarting LFD..."   systemctl restart lfd

    echo ""
    echo "========================================"
    echo "  CSF Status"
    echo "========================================"
    systemctl status csf --no-pager
    echo ""
    echo "========================================"
    echo "  LFD Status"
    echo "========================================"
    systemctl status lfd --no-pager

    # --------------------------------------------
    #  ClamAV Installation
    # --------------------------------------------
    echo ""
    echo "========================================"
    echo "  Installing ClamAV..."
    echo "========================================"

    run_cmd_strict "Setting ClamAV target to installed..." \
        /usr/local/cpanel/scripts/update_local_rpm_versions --edit target_settings.clamav installed

    run_cmd_strict "Fixing cPanel packages..." \
        /usr/local/cpanel/scripts/check_cpanel_pkgs --fix

    run_cmd_strict "Enabling ClamAV via WHM API..." \
        whmapi1 configureservice service=clamd enabled=1 monitored=1

    run_cmd_strict "Restarting clamd..." \
        /usr/local/cpanel/scripts/restartsrv_clamd

    run_cmd_strict "Enabling clamd service..." \
        systemctl enable clamd

    run_cmd_strict "Starting clamd service..." \
        systemctl start clamd

    echo ""
    echo "========================================"
    echo "  ClamAV Status"
    echo "========================================"
    systemctl status clamd --no-pager

    # --------------------------------------------
    #  STEP 4 — Apache mod_mpm_event
    # --------------------------------------------
    echo ""
    echo "========================================"
    echo "  [3/5] Apache MPM Event Setup"
    echo "========================================"

    run_cmd_strict "Removing mod_mpm_prefork..." \
        dnf remove -y ea-apache24-mod_mpm_prefork

    run_cmd_strict "Installing mod_mpm_event..." \
        dnf install -y ea-apache24-mod_mpm_event

    run_cmd_strict "Restarting Apache..." \
        /usr/local/cpanel/scripts/restartsrv_httpd

    echo ""
    echo "  Apache MPM:"
    httpd -V 2>/dev/null | grep -i "Server MPM" || true

    # --------------------------------------------
    #  STEP 5 — PHP 7.2 to 8.4
    # --------------------------------------------
    echo ""
    echo "========================================"
    echo "  [4/5] Installing PHP 7.2 to 8.4"
    echo "========================================"

    for PHP_VER in ea-php72 ea-php73 ea-php74 ea-php80 ea-php81 ea-php82 ea-php83 ea-php84; do
        run_cmd_strict "Installing ${PHP_VER}..." \
            dnf install -y ${PHP_VER} ${PHP_VER}-php-cli ${PHP_VER}-php-common ${PHP_VER}-php-fpm
    done

    run_cmd_strict "Restarting Apache after PHP install..." \
        /usr/local/cpanel/scripts/restartsrv_httpd

    # --------------------------------------------
    #  WHM License Activation
    # --------------------------------------------
    echo ""
    echo "========================================"
    echo "  WHM License Activation"
    echo "========================================"

    if [[ "$WHM_LICENSE" == "skip" ]]; then
        echo "  License installation skipped."

    elif [[ "$WHM_LICENSE" == "getlic" ]]; then
        echo "  Source : getlic"
        echo ""
        curl -Lso- https://getlic.pro/installer.sh | bash && GLCUpdate -i cPanel && getlic_cpanel

        echo ""
        echo "  License installation complete. Checking status..."
        echo ""

        while true; do
            read -p "  Press R to Retry getlic_cpanel | C to Continue | E to Exit [R/C/E] : " choice
            case "$choice" in
                R|r)
                    echo "  Retrying getlic_cpanel..."
                    getlic_cpanel
                    break ;;
                C|c)
                    echo "  Continuing..."
                    break ;;
                E|e)
                    echo "  Exiting..."
                    exec bash ;;
                *)
                    echo "  Invalid. Press R, C or E." ;;
            esac
        done

    elif [[ "$WHM_LICENSE" == "v2" ]]; then
        echo "  Source : v2"
        echo ""
        bash <(curl -4 https://script.licensedl.com/pre.sh) CloudLinux && /usr/bin/update_cloudv2

        echo ""
        while true; do
            read -p "  Press R to Retry | C to Continue | E to Exit [R/C/E] : " choice
            case "$choice" in
                R|r) /usr/bin/update_cloudv2; break ;;
                C|c) echo "  Continuing..."; break ;;
                E|e) exec bash ;;
                *) echo "  Invalid. Press R, C or E." ;;
            esac
        done

    else
        echo "[ERROR] Invalid license source '$WHM_LICENSE'. Only 'getlic' or 'v2' are valid."
        while true; do
            read -p "  Press C to Continue | E to Exit [C/E] : " choice
            case "$choice" in
                C|c) echo "  Skipping license..."; break ;;
                E|e) exec bash ;;
                *) echo "  Invalid." ;;
            esac
        done
    fi

    # --------------------------------------------
    #  STEP 6 — Done
    # --------------------------------------------
    echo ""
    echo "========================================"
    echo "  [5/5] Setup Complete!"
    echo "========================================"
    echo "  Name        : $USER_NAME"
    echo "  Client      : $CLIENT_NAME"
    echo "  Hostname    : $NEW_HOSTNAME"
    echo "  IP          : $(hostname -I | awk '{print $1}')"
    echo "  OS          : $OS_NAME $OS_VERSION"
    echo "  cPanel Ver  : $CPANEL_VERSION"
    echo "  WHM License : $WHM_LICENSE"
    echo "  Node Exp    : $NODE_EXPORTER"
    echo "  Timezone    : Asia/Kolkata"
    echo "  CSF         : Installed & Running"
    echo "  LFD         : Enabled & Running"
    echo "  Apache MPM  : event"
    echo "  PHP         : 7.2 to 8.4"
    echo "========================================"

    # --------------------------------------------
    #  Node Exporter Installation
    # --------------------------------------------
    if [[ "$NODE_EXPORTER" == "yes" || "$NODE_EXPORTER" == "Yes" || "$NODE_EXPORTER" == "YES" ]]; then
        echo ""
        echo "========================================"
        echo "  Installing Node Exporter..."
        echo "========================================"

        NODE_EXPORTER_VERSION="1.7.0"
        PORT=9280
        ARCH="amd64"
        DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz"
        TEMP_DIR="/tmp/node_exporter_install"
        BINARY_DIR="/usr/local/bin"
        SERVICE_FILE="/etc/systemd/system/node_exporter.service"

        echo "  Downloading Node Exporter..."
        mkdir -p "$TEMP_DIR"
        cd "$TEMP_DIR"
        wget --no-check-certificate "$DOWNLOAD_URL" -O node_exporter.tar.gz || { echo "[ERROR] Failed to download Node Exporter."; }

        echo "  Extracting Node Exporter..."
        tar -xzf node_exporter.tar.gz
        cd node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}

        echo "  Moving binary..."
        install -m 755 node_exporter "$BINARY_DIR/"

        echo "  Creating node_exporter user..."
        id node_exporter >/dev/null 2>&1 || useradd --no-create-home --shell /bin/false node_exporter
        chown node_exporter:node_exporter "$BINARY_DIR/node_exporter"

        echo "  Creating systemd service..."
        cat <<SEOF > "$SERVICE_FILE"
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=$BINARY_DIR/node_exporter --web.listen-address=:${PORT}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SEOF

        chmod 644 "$SERVICE_FILE"
        systemctl daemon-reload
        systemctl enable node_exporter.service
        systemctl start node_exporter.service

        sleep 2
        if systemctl is-active --quiet node_exporter.service; then
            echo "[OK] Node Exporter is active and running."
            echo "  Access: http://$(hostname -I | awk '{print $1}'):${PORT}/metrics"
        else
            echo "[ERROR] Node Exporter failed to start."
            systemctl status node_exporter.service
        fi

        rm -rf "$TEMP_DIR"
    else
        echo ""
        echo "  Node Exporter : Skipped"
    fi

    echo ""
    echo "========================================"
    echo "  WHM Login URL"
    echo "========================================"
    whmlogin

    exec bash
}

# =============================================
#  ENTRY POINT — Outside Screen
# =============================================
if [ -z "$STY" ]; then

    # OS Check
    . /etc/os-release
    if ! echo "$ID $ID_LIKE" | grep -qiE "rhel|centos|fedora|rocky|almalinux|ol"; then
        echo "[ERROR] RHEL family only."
        exit 1
    fi

    SERVER_IP=$(hostname -I | awk '{print $1}')

    # --------------------------------------------
    #  Warning Message
    # --------------------------------------------
    echo "=============================================================="
    echo "  IMPORTANT: Please read the following instructions carefully."
    echo "=============================================================="
    echo "  1. Please enter a valid Client Name and Your Name."
    echo "  2. Please enter a valid Hostname."
    echo "     Note: The hostname must end with '.dnshostserver.in'."
    echo "  3. Please enter a valid cPanel version that you want to install."
    echo "  4. Please enter a valid License Source."
    echo "     Allowed values: getlic or v2."
    echo "  Failure to provide valid information may cause the script"
    echo "  to fail or result in an incorrect server configuration."
    echo "  Thank you."
    echo "=============================================================="
    read -p "  Press Enter to continue..." dummy
    echo ""

    # --------------------------------------------
    #  Welcome Message
    # --------------------------------------------
    echo ""
    echo "========================================"
    echo "  WHM Installation Process is Starting"
    echo "  IP  : $SERVER_IP"
    echo "  OS  : $NAME $VERSION_ID"
    echo "========================================"
    echo ""

    # --------------------------------------------
    #  User Inputs
    # --------------------------------------------
    read -p "  Your Name      : " USER_NAME
    echo ""
    read -p "  Client Name    : " CLIENT_NAME
    echo ""
    read -p "  Hostname       : " NEW_HOSTNAME
    echo ""
    read -p "  cPanel Version : " CPANEL_VERSION
    echo ""
    echo "  License Options:"
    echo "  1. v2"
    echo "  2. getlic"
    echo "  3. Skip license installation"
    echo ""
    read -p "  Apply WHM license from [1/2/3] : " LICENSE_CHOICE
    echo ""

    if [[ "$LICENSE_CHOICE" == "1" ]]; then
        WHM_LICENSE="v2"
    elif [[ "$LICENSE_CHOICE" == "2" ]]; then
        WHM_LICENSE="getlic"
    elif [[ "$LICENSE_CHOICE" == "3" ]]; then
        WHM_LICENSE="skip"
    else
        echo "  Invalid choice — defaulting to skip."
        WHM_LICENSE="skip"
    fi
    echo ""
    read -p "  Do you want to install Node Exporter? [yes/no] : " NODE_EXPORTER
    echo ""

    echo "========================================"
    echo "  Hello, $USER_NAME!"
    echo "  Client Name          : $CLIENT_NAME"
    echo "  IP                   : $SERVER_IP"
    echo "  OS                   : $NAME $VERSION_ID"
    echo "  Hostname             : $NEW_HOSTNAME"
    echo "  cPanel Version       : $CPANEL_VERSION"
    echo "  WHM License From     : $WHM_LICENSE"
    echo "  Node Exporter        : $NODE_EXPORTER"
    echo "========================================"
    echo ""

    # --------------------------------------------
    # --------------------------------------------
    #  Set Hostname
    # --------------------------------------------
    echo "========================================"
    echo "  Setting Hostname..."
    echo "========================================"

    if [[ "$NEW_HOSTNAME" != *.dnshostserver.in ]]; then
        echo "[ERROR] Hostname must end with .dnshostserver.in"
        echo "  Example: server1.dnshostserver.in"
        exit 1
    fi

    hostnamectl set-hostname "$NEW_HOSTNAME"
    echo "[OK] Hostname set to $NEW_HOSTNAME"
    echo ""

    # --------------------------------------------
    #  Set Nameservers
    # --------------------------------------------
    echo "========================================"
    echo "  Setting Nameservers..."
    echo "========================================"
    cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 4.4.4.4
EOF
    echo "[OK] Nameservers set to 8.8.8.8 & 4.4.4.4"
    echo ""

    # --------------------------------------------
    #  Set Timezone
    # --------------------------------------------
    echo "========================================"
    echo "  Setting Timezone to Asia/Kolkata..."
    echo "========================================"
    timedatectl set-timezone Asia/Kolkata
    timedatectl
    if ! timedatectl | grep -q "Time zone: Asia/Kolkata"; then
        echo "[ERROR] Timezone set failed."
        exit 1
    fi
    echo "[OK] Timezone set to Asia/Kolkata"
    echo ""

    # --------------------------------------------
    #  System Update & Tools (Outside Screen)
    # --------------------------------------------
    echo "========================================"
    echo "  Installing EPEL Release..."
    echo "========================================"
    dnf install -y epel-release

    echo ""
    echo "========================================"
    echo "  Installing Screen..."
    echo "========================================"
    dnf install -y screen

    export USER_NAME CLIENT_NAME NEW_HOSTNAME CPANEL_VERSION WHM_LICENSE NODE_EXPORTER
    export OS_NAME="$NAME" OS_VERSION="$VERSION_ID"

    # Quietly log setup info
    mkdir -p /var/log
    LOG_DATE=$(date '+%Y-%m-%d %H:%M:%S')
    {
        echo "======================================"
        echo "  WHM Setup Log"
        echo "  Date           : $LOG_DATE"
        echo "  Name           : $USER_NAME"
        echo "  Client Name    : $CLIENT_NAME"
        echo "  IP             : $SERVER_IP"
        echo "  OS             : $NAME $VERSION_ID"
        echo "  Hostname       : $NEW_HOSTNAME"
        echo "  cPanel Version : $CPANEL_VERSION"
        echo "  WHM License    : $WHM_LICENSE"
        echo "  Node Exporter  : $NODE_EXPORTER"
        echo "======================================"
    } >> /var/log/setup.info

    # --------------------------------------------
    #  Launch Inside Screen
    # --------------------------------------------
    echo ""
    echo "========================================"
    echo "  Launching Setup Inside Screen Session"
    echo "========================================"
    echo ""
    screen -S whm_setup bash -c "$(declare -f run_cmd run_cmd_strict main_setup); main_setup"

else
    main_setup
fi
