#================ Удаление BD ==========================

#!/bin/bash
# Получите список всех баз данных
databases=$(uapi Mysql list_databases | python -c "import yaml, json, sys; print(json.dumps(yaml.safe_load(sys.stdin.read())))" | jq -r '.result.data[].database')

# Итерация по каждой базе данных для удаления
for db in $databases
do
  echo "Удаление базы данных $db"
  uapi Mysql delete_database name=$db
done


#================ Удаление пользователей BD ==========================

#!/bin/bash
# Получите список всех пользователей
users=$(uapi Mysql list_users | python -c "import yaml, json, sys; print(json.dumps(yaml.safe_load(sys.stdin.read())))" | jq -r '.result.data[].user')

# Итерация по каждому пользователю для удаления
for user in $users; do
  echo "Удаление пользователя $user"
    uapi Mysql delete_user name=$user
done

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++



function process_transfer () {

    clear
    while true; do

    echo "Choose an action:"
    echo ""
    echo "1. Establish server connection"
    echo "2. Start website transfer"
    echo "3. Forcefully download DB to local server"
    echo "4. Create a DB and upload dumps"
    echo "5. Transfer missing directories"
    echo "6. Replace URLs in Configs"
    echo "7. Create mailboxes (Only after adding domains)"
    echo "8. Delete All users & db in cPanel"
    echo "9. End of work"


    read -p "Choose an option (1/2/3/4/5/6/7/8/9): " CHOICE

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
            read -p "Create mailboxes? (y/n) " RESPONSE
            if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "Y" ]; then
                create_mailbox
                echo "Mailbox creation completed."
            else
                echo "Mailbox creation - Action canceled."
            fi
            ;;
        6)
            echo ""
            echo "Exit. "
            exit 0
            ;;
        7)
            clear
            read -p "Scan for missing domains? (y/n) " RESPONSE
            if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "Y" ]; then
                missing_domains
                echo "Missing domains scaning completed."
            else
                echo "Missing domains scaning - Action canceled."
            fi
            clear
            ;;
        *)

        echo "Invalid choice. Enter 1, 2, 3, 4, 5 or 6."
            ;;
    esac

done

}
