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
url="https://raw.githubusercontent.com/zDimaBY/transfer_to/master/functionsFolder/function.sh"
wget -qO- "$url" > ./functionsFolder/function.sh

# A loop to connect all files in a folder
for file in ./"$folder_path"/*
do
    if [ -f "$file" ] && [ -r "$file" ]; then
        source "$file"
    fi
done

#  ================= Start Script ==================


function process_transfer () {

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


    read -p "Choose an option (1/2/3/4/5/6/7/8/9/0): " CHOICE

    case $CHOICE in
        1)
            clear
            read -p "Establish server connection? (y/n) " RESPONSE
            if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "Y" ]; then
                id_rsa_key
                echo "Server connection established."
            else
                echo "Server connection - Action canceled."
            fi
            clear
            ;;
        2)
            clear
            read -p "Start website transfer? (y/n) " RESPONSE
            if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "Y" ]; then
            volume_of_databases ; free_space
            fi

        #  ================= Site files transfer ==========================

                transfer_files_mails_dbs

        #  ================= Copying mail directory ===================

        # Check for existence of mail directory
        if [ -d "$DESTINATION_MAIL/mail" ]; then
            mv $DESTINATION_MAIL/mail $DESTINATION_MAIL/mail_back
        fi

                rsync_email $SOURCE_MAIL $DESTINATION_MAIL

        # Check for successful execution of rsync_email
        if [ $? -eq 0 ]; then
            log "rsync_email successfully executed for domain $DOMAIN"
            # Check for existence of email directory
            if [ -d "$DESTINATION_MAIL/email" ]; then
                mv $DESTINATION_MAIL/email $DESTINATION_MAIL/mail
            fi
        else
            log "Error executing rsync_email for domain $DOMAIN"
        fi

        #  ================= Copying database dumps ==================

        # Copying DB data
        DESTINATION_DB=$DESTINATION

                rsync_db $SOURCE_DB/*.sql $DESTINATION_DB

        if [ $? -eq 0 ]; then
            log "rsync_db executed successfully"
        else
            log "Error executing rsync_db"
        fi

        #  ================= Creating a file with cron tasks ==================

            transfer_cron ; upload_cron

        clear
        echo ""
        echo "Site transfer, BD, Mail, Cron - completed. Check log  $DESTINATION/transfer_logfile.log"

            ;;
        3)
            clear
            read -p "Forcefully download DB to local server? (y/n)" RESPONSE
            if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "Y" ]; then
                scrap-db-local
                echo "Databases successful dumped locally."
            else
                echo "Databases dumped locally - Action canceled."
            fi
            clear
            ;;
        4)
            clear
            read -p "Databases will be created and corresponding dumps will be uploaded into them. Continue? (y/n) " RESPONSE
            if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "Y" ]; then
                create_db_on_cpanel ; upload_dump_on_cpanel
                echo "Database creation completed."
            else
                echo "Database creation - Action canceled."
            fi
            clear
            ;;
        5)
            clear
            read -p "Scan for missing directories? (y/n) " RESPONSE
            if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "Y" ]; then
                missing_domains
                echo "Missing directories scaning completed."
            else
                echo "Missing directories scaning - Action canceled."
            fi
            clear
            ;;
        6)
            clear
            read -p "Replace PATHs in configs? (y/n) " RESPONSE
            if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "Y" ]; then
                replace_config_urls
                echo "Replacing PATHs in Configs completed."
            else
                echo "Replacing PATHs in Configs - Action canceled."
            fi
            clear
            ;;
        7)
            clear
            echo "1. Create domains"
            echo "2. Delete domains"
            read -p "Choose an action (1/2) " RESPONSE

            case $RESPONSE in
              1)
                read -p "Create domains? (y/n) " RESPONSE
                if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "Y" ]; then
                    create_domain
                    echo "Domains creating completed."
                else
                    echo "Domains creating - Action canceled."
                fi
                ;;
              2)
                read -p "Delete domains? (y/n) " RESPONSE
                if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "Y" ]; then
                    delete_domain
                    echo "Domains deletion completed."
                else
                    echo "Domains deletion - Action canceled."
                fi
                ;;
              *)
                echo "Invalid option"
                ;;
            esac
                ;;
        8)
            clear
            read -p "Create mailboxes? (y/n) " RESPONSE
            if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "Y" ]; then
                create_mailbox
                echo "Mailbox creation completed."
            else
                echo "Mailbox creation - Action canceled."
            fi
            ;;
        9)
            clear
            read -p "Delete All users & db in cPanel? (y/n) " RESPONSE
            if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "Y" ]; then
                delete_all_db_user_cpanel
                echo "Deleting All users & db in cPanel completed."
            else
                echo "Deleting All users & db in cPanel - Action canceled."
            fi
            clear
            ;;
        0)
            echo ""
            echo "Exit. "
            exit 0
            ;;  
        *)

        echo "Invalid choice. Enter 1, 2, 3, 4, 5, 6, 7, 8, 9 or 0."
            ;;
    esac

done

}

    process_transfer
    log "Script started"
