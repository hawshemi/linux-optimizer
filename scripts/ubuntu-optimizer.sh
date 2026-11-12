#!/bin/bash
# https://github.com/hawshemi/Linux-Optimizer


# Green, Yellow & Red Messages.
green_msg() {
    tput setaf 2
    echo "[*] ----- $1"
    tput sgr0
}

yellow_msg() {
    tput setaf 3
    echo "[*] ----- $1"
    tput sgr0
}

red_msg() {
    tput setaf 1
    echo "[*] ----- $1"
    tput sgr0
}


# Declare Paths & Settings.
SYS_PATH="/etc/sysctl.conf"
PROF_PATH="/etc/profile"
SSH_PORT=""
SSH_PATH="/etc/ssh/sshd_config"
SWAP_PATH="/swapfile"
SWAP_SIZE=2G


# Root
check_if_running_as_root() {
    ## If you want to run as another user, please modify $EUID to be owned by this user
    if [[ "$EUID" -ne '0' ]]; then
      echo 
      red_msg 'Error: You must run this script as root!'
      echo 
      sleep 0.5
      exit 1
    fi
}


# Check Root
check_if_running_as_root
sleep 0.5


# Ask Reboot
ask_reboot() {
    yellow_msg 'Reboot now? (Recommended) (y/n)'
    echo 
    while true; do
        read choice
        echo 
        if [[ "$choice" == 'y' || "$choice" == 'Y' ]]; then
            sleep 0.5
            reboot
            exit 0
        fi
        if [[ "$choice" == 'n' || "$choice" == 'N' ]]; then
            break
        fi
    done
}


# Update & Upgrade & Remove & Clean
complete_update() {
    echo 
    yellow_msg 'Updating the System... (This can take a while.)'
    echo 
    sleep 0.5

    sudo apt -q update
    sudo apt -y upgrade
    sudo apt -y full-upgrade
    sudo apt -y autoremove
    sleep 0.5

    ## Again :D
    sudo apt -y -q autoclean
    sudo apt -y clean
    sudo apt -q update
    sudo apt -y upgrade
    sudo apt -y full-upgrade
    sudo apt -y autoremove --purge

    echo 
    green_msg 'System Updated & Cleaned Successfully.'
    echo 
    sleep 0.5
}


# Disable Terminal Ads
disable_terminal_ads() {
    echo 
    yellow_msg 'Disabling Terminal Ads...'
    echo 
    sleep 0.5

    sed -i 's/ENABLED=1/ENABLED=0/g' /etc/default/motd-news
    pro config set apt_news=false

    echo 
    green_msg 'Terminal Ads Disabled.'
    echo 
    sleep 0.5
}


# Install XanMod Kernel
install_xanmod() {
    echo 
    yellow_msg 'Checking XanMod...'
    echo 
    sleep 0.5

    if uname -r | grep -q 'xanmod'; then
        green_msg 'XanMod is already installed.'
        echo 
        sleep 0.5
    else
        echo 
        yellow_msg 'XanMod not found. Installing XanMod Kernel...'
        echo 
        sleep 0.5

        ## Update, Upgrade & Install dependencies
        sudo apt update -q
        sudo apt upgrade -y
        sudo apt install wget curl gpg -y

        ## Check the CPU level
        cpu_level=$(awk -f - <<EOF
        BEGIN {
            while (!/flags/) if (getline < "/proc/cpuinfo" != 1) exit 1
            if (/lm/&&/cmov/&&/cx8/&&/fpu/&&/fxsr/&&/mmx/&&/syscall/&&/sse2/) level = 1
            if (level == 1 && /cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/) level = 2
            if (level == 2 && /avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/) level = 3
            if (level == 3 && /avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/) level = 4
            if (level > 0) { print level; exit level + 1 }
            exit 1
        }
EOF
        )

        if [ "$cpu_level" -ge 1 ] && [ "$cpu_level" -le 4 ]; then
            echo 
            yellow_msg "CPU Level: v$cpu_level"
            echo 

            ## Add the XanMod repository key
            # Define a temporary file for the GPG key
            tmp_keyring="/tmp/xanmod-archive-keyring.gpg"

            # Try downloading the GPG key from the XanMod link first
            if ! wget -qO $tmp_keyring https://dl.xanmod.org/archive.key || ! [ -s $tmp_keyring ]; then
                # If the first attempt fails, try the GitLab link
                if ! wget -qO $tmp_keyring https://gitlab.com/afrd.gpg || ! [ -s $tmp_keyring ]; then
                    echo "Both attempts to download the GPG key failed or the file was empty. Exiting."
                    exit 1
                fi
            fi

            # If we reach this point, it means we have a non-empty GPG file
            # Now dearmor the GPG key and move to the final location
            sudo gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg $tmp_keyring

            # Clean up the temporary file
            rm -f $tmp_keyring

            ## Add the XanMod repository (suite is the distro codename, per xanmod.org)
            local codename list=/etc/apt/sources.list.d/xanmod-release.list
            codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
            echo "deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org $codename main" | sudo tee $list

            ## Install XanMod: x64v4 has no build (use v3); x64v1 and Debian oldstable only have LTS
            local level=$(( cpu_level > 3 ? 3 : cpu_level ))
            if sudo apt update -q && { sudo apt install -y "linux-xanmod-x64v$level" || sudo apt install -y "linux-xanmod-lts-x64v$level"; }; then
                sudo apt autoremove --purge -y

                echo 
                green_msg "XanMod Kernel Installed. Reboot to Apply the new Kernel."
                echo 
                sleep 1
            else
                # Release not in the XanMod repo: drop it so later apt updates don't fail
                sudo rm -f $list
                sudo apt update -q

                echo 
                red_msg "XanMod is not available for '$codename'. Skipped. (Supported releases: xanmod.org)"
                echo 
                sleep 2
            fi
        else
            echo 
            red_msg "Unsupported CPU. (Check the supported CPUs at xanmod.org)"
            echo 
            sleep 2
        fi
        
    fi
}


# Install useful packages
installations() {
    echo 
    yellow_msg 'Installing Useful Packages...'
    echo 
    sleep 0.5

    ## Networking packages
    sudo apt -y install apt-transport-https

    ## System utilities
    sudo apt -y install apt-utils bash-completion busybox ca-certificates cron curl gnupg2 locales lsb-release nano preload screen software-properties-common ufw unzip vim wget xxd zip

    ## Programming and development tools
    sudo apt -y install autoconf automake bash-completion build-essential git libtool make pkg-config python3 python3-pip

    ## Additional libraries and dependencies
    sudo apt -y install bc binutils binutils-common binutils-x86-64-linux-gnu ubuntu-keyring haveged jq libsodium-dev libsqlite3-dev libssl-dev packagekit qrencode socat

    ## Miscellaneous
    sudo apt -y install dialog htop net-tools

    echo 
    green_msg 'Useful Packages Installed Succesfully.'
    echo 
    sleep 0.5
}


# Enable packages at server boot
enable_packages() {
    sudo systemctl enable cron haveged preload
    echo 
    green_msg 'Packages Enabled Successfully.'
    echo
    sleep 0.5
}


## Swap Maker
swap_maker() {
    echo 
    yellow_msg 'Making SWAP Space...'
    echo 
    sleep 0.5

    ## Make Swap
    sudo fallocate -l $SWAP_SIZE $SWAP_PATH  ## Allocate size
    sudo chmod 600 $SWAP_PATH                ## Set proper permission
    sudo mkswap $SWAP_PATH                   ## Setup swap         
    sudo swapon $SWAP_PATH                   ## Enable swap
    echo "$SWAP_PATH   none    swap    sw    0   0" >> /etc/fstab ## Add to fstab
    echo 
    green_msg 'SWAP Created Successfully.'
    echo
    sleep 0.5
}


# SYSCTL Optimization
sysctl_optimizations() {
    ## Make a backup of the original sysctl.conf file
    cp $SYS_PATH /etc/sysctl.conf.bak

    echo 
    yellow_msg 'Default sysctl.conf file Saved. Directory: /etc/sysctl.conf.bak'
    echo 
    sleep 1

    echo 
    yellow_msg 'Optimizing the Network...'
    echo 
    sleep 0.5

    sed -i -e '/fs.file-max/d' \
        -e '/net.core.default_qdisc/d' \
        -e '/net.core.netdev_max_backlog/d' \
        -e '/net.core.optmem_max/d' \
        -e '/net.core.somaxconn/d' \
        -e '/net.core.rmem_max/d' \
        -e '/net.core.wmem_max/d' \
        -e '/net.core.rmem_default/d' \
        -e '/net.core.wmem_default/d' \
        -e '/net.ipv4.tcp_rmem/d' \
        -e '/net.ipv4.tcp_wmem/d' \
        -e '/net.ipv4.tcp_congestion_control/d' \
        -e '/net.ipv4.tcp_fastopen/d' \
        -e '/net.ipv4.tcp_fin_timeout/d' \
        -e '/net.ipv4.tcp_keepalive_time/d' \
        -e '/net.ipv4.tcp_keepalive_probes/d' \
        -e '/net.ipv4.tcp_keepalive_intvl/d' \
        -e '/net.ipv4.tcp_max_orphans/d' \
        -e '/net.ipv4.tcp_max_syn_backlog/d' \
        -e '/net.ipv4.tcp_max_tw_buckets/d' \
        -e '/net.ipv4.tcp_mem/d' \
        -e '/net.ipv4.tcp_mtu_probing/d' \
        -e '/net.ipv4.tcp_notsent_lowat/d' \
        -e '/net.ipv4.tcp_retries2/d' \
        -e '/net.ipv4.tcp_sack/d' \
        -e '/net.ipv4.tcp_dsack/d' \
        -e '/net.ipv4.tcp_slow_start_after_idle/d' \
        -e '/net.ipv4.tcp_window_scaling/d' \
        -e '/net.ipv4.tcp_adv_win_scale/d' \
        -e '/net.ipv4.tcp_ecn/d' \
        -e '/net.ipv4.tcp_ecn_fallback/d' \
        -e '/net.ipv4.tcp_syncookies/d' \
        -e '/net.ipv4.udp_mem/d' \
        -e '/net.ipv6.conf.all.disable_ipv6/d' \
        -e '/net.ipv6.conf.default.disable_ipv6/d' \
        -e '/net.ipv6.conf.lo.disable_ipv6/d' \
        -e '/net.unix.max_dgram_qlen/d' \
        -e '/vm.min_free_kbytes/d' \
        -e '/vm.swappiness/d' \
        -e '/vm.vfs_cache_pressure/d' \
        -e '/net.ipv4.conf.default.rp_filter/d' \
        -e '/net.ipv4.conf.all.rp_filter/d' \
        -e '/net.ipv4.conf.all.accept_source_route/d' \
        -e '/net.ipv4.conf.default.accept_source_route/d' \
        -e '/net.ipv4.neigh.default.gc_thresh1/d' \
        -e '/net.ipv4.neigh.default.gc_thresh2/d' \
        -e '/net.ipv4.neigh.default.gc_thresh3/d' \
        -e '/net.ipv4.neigh.default.gc_stale_time/d' \
        -e '/net.ipv4.conf.default.arp_announce/d' \
        -e '/net.ipv4.conf.lo.arp_announce/d' \
        -e '/net.ipv4.conf.all.arp_announce/d' \
        -e '/kernel.panic/d' \
        -e '/vm.dirty_ratio/d' \
        -e '/vm.overcommit_memory/d' \
        -e '/vm.overcommit_ratio/d' \
        -e '/^#/d' \
        -e '/^$/d' \
        "$SYS_PATH"


    ## Add new parameters. Read More: https://github.com/hawshemi/Linux-Optimizer/blob/main/files/sysctl.conf

cat <<EOF >> "$SYS_PATH"


################################################################
################################################################


# /etc/sysctl.conf
# These parameters in this file will be added/updated to the sysctl.conf file.
# Read More: https://github.com/hawshemi/Linux-Optimizer/blob/main/files/sysctl.conf


## File system settings
## ----------------------------------------------------------------

# Set the maximum number of open file descriptors
fs.file-max = 67108864


## Network core settings
## ----------------------------------------------------------------

# Specify default queuing discipline for network devices
net.core.default_qdisc = fq

# Configure maximum network device backlog
net.core.netdev_max_backlog = 32768

# Set maximum socket receive buffer
net.core.optmem_max = 262144

# Define maximum backlog of pending connections
net.core.somaxconn = 65536

# Configure maximum TCP receive buffer size
net.core.rmem_max = 33554432

# Set default TCP receive buffer size
net.core.rmem_default = 1048576

# Configure maximum TCP send buffer size
net.core.wmem_max = 33554432

# Set default TCP send buffer size
net.core.wmem_default = 1048576


## TCP settings
## ----------------------------------------------------------------

# Define socket receive buffer sizes
net.ipv4.tcp_rmem = 16384 1048576 33554432

# Specify socket send buffer sizes
net.ipv4.tcp_wmem = 16384 1048576 33554432

# Set TCP congestion control algorithm to BBR
net.ipv4.tcp_congestion_control = bbr

# Configure TCP FIN timeout period
net.ipv4.tcp_fin_timeout = 25

# Set keepalive time (seconds)
net.ipv4.tcp_keepalive_time = 1200

# Configure keepalive probes count and interval
net.ipv4.tcp_keepalive_probes = 7
net.ipv4.tcp_keepalive_intvl = 30

# Define maximum orphaned TCP sockets
net.ipv4.tcp_max_orphans = 819200

# Set maximum TCP SYN backlog
net.ipv4.tcp_max_syn_backlog = 20480

# Configure maximum TCP Time Wait buckets
net.ipv4.tcp_max_tw_buckets = 1440000

# Define TCP memory limits
net.ipv4.tcp_mem = 65536 1048576 33554432

# Enable TCP MTU probing
net.ipv4.tcp_mtu_probing = 1

# Define minimum amount of data in the send buffer before TCP starts sending
net.ipv4.tcp_notsent_lowat = 32768

# Specify retries for TCP socket to establish connection
net.ipv4.tcp_retries2 = 8

# Enable TCP SACK and DSACK
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1

# Disable TCP slow start after idle
net.ipv4.tcp_slow_start_after_idle = 0

# Enable TCP window scaling
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = -2

# Enable TCP ECN
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1

# Enable the use of TCP SYN cookies to help protect against SYN flood attacks
net.ipv4.tcp_syncookies = 1


## UDP settings
## ----------------------------------------------------------------

# Define UDP memory limits
net.ipv4.udp_mem = 65536 1048576 33554432


## IPv6 settings
## ----------------------------------------------------------------

# Enable IPv6
#net.ipv6.conf.all.disable_ipv6 = 0

# Enable IPv6 by default
#net.ipv6.conf.default.disable_ipv6 = 0

# Enable IPv6 on the loopback interface (lo)
#net.ipv6.conf.lo.disable_ipv6 = 0


## UNIX domain sockets
## ----------------------------------------------------------------

# Set maximum queue length of UNIX domain sockets
net.unix.max_dgram_qlen = 256


## Virtual memory (VM) settings
## ----------------------------------------------------------------

# Specify minimum free Kbytes at which VM pressure happens
vm.min_free_kbytes = 65536

# Define how aggressively swap memory pages are used
vm.swappiness = 10

# Set the tendency of the kernel to reclaim memory used for caching of directory and inode objects
vm.vfs_cache_pressure = 250


## Network Configuration
## ----------------------------------------------------------------

# Configure reverse path filtering
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.all.rp_filter = 2

# Disable source route acceptance
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Neighbor table settings
net.ipv4.neigh.default.gc_thresh1 = 512
net.ipv4.neigh.default.gc_thresh2 = 2048
net.ipv4.neigh.default.gc_thresh3 = 16384
net.ipv4.neigh.default.gc_stale_time = 60

# ARP settings
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2

# Kernel panic timeout
kernel.panic = 1

# Set dirty page ratio for virtual memory
vm.dirty_ratio = 20

# Strictly limits memory allocation to physical RAM + swap, preventing overcommit and reducing OOM risks.
vm.overcommit_memory = 2

# Sets overcommit to 100% of RAM when enabled, but ignored here since overcommit_memory = 2 disables it.
vm.overcommit_ratio = 100


################################################################
################################################################


EOF

    sudo sysctl -p
    
    echo 
    green_msg 'Network is Optimized.'
    echo 
    sleep 0.5
}


# Function to find the SSH port and set it in the SSH_PORT variable
find_ssh_port() {
    echo 
    yellow_msg "Finding SSH port..."
    echo 
    
    ## Check if the SSH configuration file exists
    if [ -e "$SSH_PATH" ]; then
        ## Use grep to search for the 'Port' directive in the SSH configuration file
        SSH_PORT=$(grep -oP '^Port\s+\K\d+' "$SSH_PATH" 2>/dev/null)

        if [ -n "$SSH_PORT" ]; then
            echo 
            green_msg "SSH port found: $SSH_PORT"
            echo 
            sleep 0.5
        else
            echo 
            green_msg "SSH port is default 22."
            echo 
            SSH_PORT=22
            sleep 0.5
        fi
    else
        red_msg "SSH configuration file not found at $SSH_PATH"
    fi
}


# Remove old SSH config to prevent duplicates.
remove_old_ssh_conf() {
    ## Make a backup of the original sshd_config file
    cp $SSH_PATH /etc/ssh/sshd_config.bak

    echo 
    yellow_msg 'Default SSH Config file Saved. Directory: /etc/ssh/sshd_config.bak'
    echo 
    sleep 1

    ## Remove these lines
    sed -i -e 's/#UseDNS yes/UseDNS no/' \
        -e 's/#Compression no/Compression yes/' \
        -e 's/Ciphers .*/Ciphers aes256-ctr,chacha20-poly1305@openssh.com/' \
        -e '/MaxAuthTries/d' \
        -e '/MaxSessions/d' \
        -e '/TCPKeepAlive/d' \
        -e '/ClientAliveInterval/d' \
        -e '/ClientAliveCountMax/d' \
        -e '/AllowAgentForwarding/d' \
        -e '/AllowTcpForwarding/d' \
        -e '/GatewayPorts/d' \
        -e '/PermitTunnel/d' \
        -e '/X11Forwarding/d' "$SSH_PATH"

}
# Update SSH config
update_sshd_conf() {
    echo 
    yellow_msg 'Optimizing SSH...'
    echo 
    sleep 0.5

    ## Enable TCP keep-alive messages
    echo "TCPKeepAlive yes" | tee -a "$SSH_PATH"

    ## Configure client keep-alive messages
    echo "ClientAliveInterval 3000" | tee -a "$SSH_PATH"
    echo "ClientAliveCountMax 100" | tee -a "$SSH_PATH"

    ## Allow TCP forwarding
    echo "AllowTcpForwarding yes" | tee -a "$SSH_PATH"

    ## Enable gateway ports
    echo "GatewayPorts yes" | tee -a "$SSH_PATH"

    ## Enable tunneling
    echo "PermitTunnel yes" | tee -a "$SSH_PATH"

    ## Enable X11 graphical interface forwarding
    echo "X11Forwarding yes" | tee -a "$SSH_PATH"

    ## Restart the SSH service to apply the changes
    sudo systemctl restart ssh

    echo 
    green_msg 'SSH is Optimized.'
    echo 
    sleep 0.5
}


# System Limits Optimizations
limits_optimizations() {
    echo
    yellow_msg 'Optimizing System Limits...'
    echo 
    sleep 0.5

    ## Clear old ulimits
    sed -i '/ulimit -c/d' $PROF_PATH
    sed -i '/ulimit -d/d' $PROF_PATH
    sed -i '/ulimit -f/d' $PROF_PATH
    sed -i '/ulimit -i/d' $PROF_PATH
    sed -i '/ulimit -l/d' $PROF_PATH
    sed -i '/ulimit -m/d' $PROF_PATH
    sed -i '/ulimit -n/d' $PROF_PATH
    sed -i '/ulimit -q/d' $PROF_PATH
    sed -i '/ulimit -s/d' $PROF_PATH
    sed -i '/ulimit -t/d' $PROF_PATH
    sed -i '/ulimit -u/d' $PROF_PATH
    sed -i '/ulimit -v/d' $PROF_PATH
    sed -i '/ulimit -x/d' $PROF_PATH
    sed -i '/ulimit -s/d' $PROF_PATH


    ## Add new ulimits
    ## The maximum size of core files created.
    echo "ulimit -c unlimited" | tee -a $PROF_PATH

    ## The maximum size of a process's data segment
    echo "ulimit -d unlimited" | tee -a $PROF_PATH

    ## The maximum size of files created by the shell (default option)
    echo "ulimit -f unlimited" | tee -a $PROF_PATH

    ## The maximum number of pending signals
    echo "ulimit -i unlimited" | tee -a $PROF_PATH

    ## The maximum size that may be locked into memory
    echo "ulimit -l unlimited" | tee -a $PROF_PATH

    ## The maximum memory size
    echo "ulimit -m unlimited" | tee -a $PROF_PATH

    ## The maximum number of open file descriptors
    echo "ulimit -n 1048576" | tee -a $PROF_PATH

    ## The maximum POSIX message queue size
    echo "ulimit -q unlimited" | tee -a $PROF_PATH

    ## The maximum stack size
    echo "ulimit -s -H 65536" | tee -a $PROF_PATH
    echo "ulimit -s 32768" | tee -a $PROF_PATH

    ## The maximum number of seconds to be used by each process.
    echo "ulimit -t unlimited" | tee -a $PROF_PATH

    ## The maximum number of processes available to a single user
    echo "ulimit -u unlimited" | tee -a $PROF_PATH

    ## The maximum amount of virtual memory available to the process
    echo "ulimit -v unlimited" | tee -a $PROF_PATH

    ## The maximum number of file locks
    echo "ulimit -x unlimited" | tee -a $PROF_PATH


    echo 
    green_msg 'System Limits are Optimized.'
    echo 
    sleep 0.5
}


# UFW Optimizations
ufw_optimizations() {
    echo
    yellow_msg 'Installing & Optimizing UFW...'
    echo 
    sleep 0.5

    ## Purge firewalld to install UFW.
    sudo apt -y purge firewalld
    
    ## Install UFW if it isn't installed.
    sudo apt update -q
    sudo apt install -y ufw

    ## Disable UFW
    sudo ufw disable

    ## Open default ports.
    sudo ufw allow $SSH_PORT
    sudo ufw allow 80/tcp
    sudo ufw allow 80/udp
    sudo ufw allow 443/tcp
    sudo ufw allow 443/udp
    sleep 0.5

    ## Change the UFW config to use System config.
    sed -i 's+/etc/ufw/sysctl.conf+/etc/sysctl.conf+gI' /etc/default/ufw

    ## Enable & Reload
    echo "y" | sudo ufw enable
    sudo ufw reload
    echo 
    green_msg 'UFW is Installed & Optimized. (Open your custom ports manually.)'
    echo 
    sleep 0.5
}


# Show the Menu
show_menu() {
    echo 
    yellow_msg 'Choose One Option: '
    echo 
    green_msg '1  - Apply Everything + XanMod Kernel. (RECOMMENDED)'
    echo
    green_msg '2  - Install XanMod Kernel.'
    echo 
    green_msg '3  - Complete Update + Useful Packages + Make SWAP + Optimize Network, SSH & System Limits + UFW'
    green_msg '4  - Complete Update + Make SWAP + Optimize Network, SSH & System Limits + UFW'
    green_msg '5  - Complete Update + Make SWAP + Optimize Network, SSH & System Limits'
    echo 
    green_msg '6  - Complete Update & Clean the OS.'
    green_msg '7  - Install Useful Packages.'
    green_msg '8  - Make SWAP (2Gb).'
    green_msg '9  - Optimize the Network, SSH & System Limits.'
    echo 
    green_msg '10 - Optimize the Network settings.'
    green_msg '11 - Optimize the SSH settings.'
    green_msg '12 - Optimize the System Limits.'
    echo 
    green_msg '13 - Install & Optimize UFW.'
    echo 
    red_msg 'q - Exit.'
    echo 
}


# Choosing Program
main() {
    while true; do
        show_menu
        read -p 'Enter Your Choice: ' choice
        case $choice in
        1)
            apply_everything

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;

        2)
            complete_update
            sleep 0.5

            install_xanmod
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
        3)
            complete_update
            sleep 0.5

            installations
            enable_packages
            sleep 0.5

            swap_maker
            sleep 0.5

            sysctl_optimizations
            sleep 0.5

            remove_old_ssh_conf
            sleep 0.5

            update_sshd_conf
            sleep 0.5

            limits_optimizations
            sleep 0.5

            find_ssh_port
            ufw_optimizations
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
        4)
            complete_update
            sleep 0.5

            swap_maker
            sleep 0.5

            sysctl_optimizations
            sleep 0.5

            remove_old_ssh_conf
            sleep 0.5

            update_sshd_conf
            sleep 0.5

            limits_optimizations
            sleep 0.5

            find_ssh_port
            ufw_optimizations
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
        5)
            complete_update
            sleep 0.5

            swap_maker
            sleep 0.5

            sysctl_optimizations
            sleep 0.5

            remove_old_ssh_conf
            sleep 0.5

            update_sshd_conf
            sleep 0.5

            limits_optimizations
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
        6)
            complete_update
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
            
        7)
            complete_update
            sleep 0.5

            installations
            enable_packages
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
        8)
            swap_maker
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
        9)
            sysctl_optimizations
            sleep 0.5

            remove_old_ssh_conf
            sleep 0.5

            update_sshd_conf
            sleep 0.5

            limits_optimizations
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
        10)
            sysctl_optimizations
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ;;
        11)
            remove_old_ssh_conf
            sleep 0.5

            update_sshd_conf
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ;;
        12)
            limits_optimizations
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ask_reboot
            ;;
        13)
            find_ssh_port
            ufw_optimizations
            sleep 0.5

            echo 
            green_msg '========================='
            green_msg  'Done.'
            green_msg '========================='

            ;;
        q)
            exit 0
            ;;

        *)
            red_msg 'Wrong input!'
            ;;
        esac
    done
}


# Apply Everything
apply_everything() {

    complete_update
    sleep 0.5

    disable_terminal_ads
    sleep 0.5

    install_xanmod
    sleep 0.5 

    installations
    enable_packages
    sleep 0.5

    swap_maker
    sleep 0.5

    sysctl_optimizations
    sleep 0.5

    remove_old_ssh_conf
    sleep 0.5

    update_sshd_conf
    sleep 0.5

    limits_optimizations
    sleep 0.5
    
    find_ssh_port
    ufw_optimizations
    sleep 0.5
}


main
