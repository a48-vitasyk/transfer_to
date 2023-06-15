#!/bin/bash

# Access data
USER_ISP=""
PASSWORD=""
HOSTNAME=""
TICKET=""  # number ticket for slack
OAUTH_TOKEN="" # Token Slack Bot
BOT_ID=""
WORKER=""
PASS_CPANEL=""
USER_CPANEL=$(whoami)
HOST_CPANEL=$(hostname)

# Authentication data
authinfo="$USER_ISP:$PASSWORD"


URL="https://$HOSTNAME:1500"
IP_REMOTE_SERVER=$(dig +short $(echo "$URL" | awk -F[/:] '{print $4}'))
#IP_REMOTE_SERVER=$(getent ahostsv4 $(echo "$URL" | awk -F[/:] '{print $4}') | awk '{print $1; exit}')

#WEB
SOURCE="/var/www/$USER_ISP/data/www"
DESTINATION="/home/$USER_CPANEL"

# eMail
SOURCE_MAIL="/var/www/$USER_ISP/data/email"
DESTINATION_MAIL=$DESTINATION


# BD
SOURCE_DB="/var/www/$USER_ISP/data/www/database"

#Log
LOGFILE="$DESTINATION/transfer_logfile.log"

# The path to the file folder
folder_path="functionsFolder"
mkdir -p $folder_path

# url on functions
urls=(
  "https://raw.githubusercontent.com/zDimaBY/transfer_to/master/functionsFolder/function.sh"
  "https://raw.githubusercontent.com/zDimaBY/transfer_to/master/functionsFolder/1_server_connection.sh"
  "https://raw.githubusercontent.com/zDimaBY/transfer_to/master/functionsFolder/2_website_transfer.sh"
  "https://raw.githubusercontent.com/zDimaBY/transfer_to/master/functionsFolder/3_download_db.sh"
  "https://raw.githubusercontent.com/zDimaBY/transfer_to/master/functionsFolder/4_create_db_cpanel.sh"
  "https://raw.githubusercontent.com/zDimaBY/transfer_to/master/functionsFolder/5_transfer_directories.sh"
  "https://raw.githubusercontent.com/zDimaBY/transfer_to/master/functionsFolder/6_replace_paths.sh"
  "https://raw.githubusercontent.com/zDimaBY/transfer_to/master/functionsFolder/7_manage_domains.sh"
  "https://raw.githubusercontent.com/zDimaBY/transfer_to/master/functionsFolder/8_create_mailboxes.sh"
  "https://raw.githubusercontent.com/zDimaBY/transfer_to/master/functionsFolder/9_delete_users_db_cpanel.sh"
  "https://raw.githubusercontent.com/zDimaBY/transfer_to/master/functionsFolder/0_end_work.sh"
)
echo "Loading script, please wait."
for url in "${urls[@]}"; do
  filename=$(basename "$url")
  wget -qO- "$url" > "./$folder_path/$filename"
done

# A loop to connect all files in a folder
for file in ./$folder_path/*
do
    if [ -f "$file" ] && [ -r "$file" ]; then
        source "$file"
    fi
done

#  ================= Start Script ==================

function process_transfer() {
    clear
    while true; do
        echo "Choose an action:"
        echo ""
        echo "1. Establish server connection"
        echo "2. Start website transfer"
        echo "3. Forcefully download DB to local server"
        echo "4. Create DB and upload dumps in cPanel"
        echo "5. Transfer missing directories"
        echo "6. Replace PATHs in configs"
        echo "7. Create/Delete DOMAINS in cPanel"
        echo "8. Create mailboxes (Only after adding domains)"
        echo "9. Delete all users & db in cPanel"
        echo "0. End of work"
        echo ""

        read -p "Choose an option (1/2/3/4/5/6/7/8/9/0): " choice

        case $choice in
            1) establish_server_connection ;;
            2) start_website_transfer ;;
            3) forcefully_download_db ;;
            4) create_db_and_upload_dumps ;;
            5) transfer_missing_directories ;;
            6) replace_paths_in_configs ;;
            7) manage_domains ;;
            8) create_mailboxes ;;
            9) delete_all_users_and_db ;;
            0)
                echo ""
                fun_exit
                exit 0
                ;;
            *)
                echo "Invalid choice. Enter 1, 2, 3, 4, 5, 6, 7, 8, 9, or 0."
                ;;
        esac
    done
}

process_transfer
log "Script started"
