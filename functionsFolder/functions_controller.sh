function log () {
    local message=$1
    echo "$(date): $message" >> $LOGFILE
}

function scrap-db () {
    # Get a list of all databases and corresponding hosts
    DBS_HOSTS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=db" | jq -r '[.doc.elem[] | {"name": .name."$", "host": .dbhost."$"}]')
    echo "DBS_HOSTS: $DBS_HOSTS"

    # Going through each database
    for row in $(echo "${DBS_HOSTS}" | jq -r '.[] | @base64'); do
        _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
        }
        DB=$(_jq '.name')
        DB_HOST=$(_jq '.host')

        echo -e "Processing DB:\n$DB with host $DB_HOST"

        # Parse port number from DB host address
        DB_PORT=$(echo $DB_HOST | grep -o -E ':[0-9]+' | cut -d: -f2)
        if [ -z "$DB_PORT" ]
        then
            DB_PORT=3306
        fi
        echo -e "DB_PORT:\n$DB_PORT"

        # Get the database users
        DB_USERS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=db.users&elname='%27$DB%27'&elid=$DB->mysql->$USER_ISP" | jq -r '.doc.elem[] | .name."$"')
        echo -e "DB_USERS:\n$DB_USERS"

        for DB_USER in $DB_USERS; do
            # Get the database password for each user
            DB_PASS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=db.users.edit&elname=$DB_USER&elid=$DB_USER&plid=$DB->mysql->$USER_ISP" | jq -r '.doc.password."$"')
            echo -e "DB_PASS for $DB_USER:\n$DB_PASS"

            # Directory on the remote server
            REMOTE_DIR="/var/www/$USER_ISP/data/www/database/"

            # Create directory on the remote server
            sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER_ISP@$IP_REMOTE_SERVER "mkdir -p $REMOTE_DIR"

            # Dump the database on the remote server
            sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER_ISP@$IP_REMOTE_SERVER "mysqldump -h 127.0.0.1 --port $DB_PORT -u$DB_USER -p$DB_PASS $DB > $REMOTE_DIR/${DB_USER}_${DB}_dump.sql"

            # Check if dump was successful
            if [ $? -ne 0 ]; then
                # If not, try without specifying host and port
                sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER_ISP@$IP_REMOTE_SERVER "mysqldump -u$DB_USER -p$DB_PASS $DB > $REMOTE_DIR/${DB_USER}_${DB}_dump.sql"
            fi

            # Write the information about the database, the user, the password and the dump file
            echo "$DB_PASS:${DB_USER}_${DB}_dump.sql" >> db_info.txt
            log "${DB_USER}_${DB}_dump.sql  wrote  >> db_info.txt"
        done
    done
    curl -X POST -H "Authorization: Bearer $OAUTH_TOKEN" -H 'Content-type: application/json;charset=utf-8' --data "{
                       \"channel\":\"$BOT_ID\",
                       \"attachments\": [
                           {
                               \"color\": \"#36a64f\",
                               \"blocks\": [
                                   {
                                       \"type\": \"header\",
                                       \"text\": {
                                           \"type\": \"plain_text\",
                                           \"text\": \"Crated DATABASE dumps for $USER_CPANEL COMPLITED - $WORKER\",
                                           \"emoji\": true
                                       }
                                   },
                                   {
                                       \"type\": \"divider\"
                                   },
                                   {
                                       \"type\": \"section\",
                                       \"text\": {
                                           \"type\": \"mrkdwn\",
                                           \"text\": \"<https://api.zomro.com/billmgr?/|Ticket #: $TICKET>\"
                                       }
                                   },

                               ]
                           }
                       ]
                   }" https://slack.com/api/chat.postMessage
}

function rsync_from () {
    local source=$1
    local destination=$2

    # Transfer the archive to the local server
    rsync -azh --info=progress2 -e "ssh -i ~/.ssh/id_rsa" $USER_ISP@$IP_REMOTE_SERVER:$source $destination

    echo "Transfer complete. Data was transferred to the following destinations:"
    echo $destination
    log "Transfer complete. Data was transferred to the following $destination."
}

# Function controller -------------------------------------------------------------------------
function establish_server_connection() {
    clear
    read -p "Establish server connection? (y/n) " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        id_rsa_key
        echo "Server connection established."
    else
        echo "Server connection - Action canceled."
    fi
    clear
}

function start_website_transfer() {
    clear
    read -p "Start website transfer? (y/n) " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        volume_of_databases
        free_space

        # Site files transfer
        transfer_files_mails_dbs

        # Copying mail directory
        if [ -d "$DESTINATION_MAIL/mail" ]; then
            mv "$DESTINATION_MAIL/mail" "$DESTINATION_MAIL/mail_back"
        fi
        rsync_email "$SOURCE_MAIL" "$DESTINATION_MAIL"
        if [ $? -eq 0 ]; then
            log "rsync_email successfully executed for domain $DOMAIN"
            if [ -d "$DESTINATION_MAIL/email" ]; then
                mv "$DESTINATION_MAIL/email" "$DESTINATION_MAIL/mail"
            fi
        else
            log "Error executing rsync_email for domain $DOMAIN"
        fi

        # Copying database dumps
        DESTINATION_DB="$DESTINATION"
        rsync_db "$SOURCE_DB"/*.sql "$DESTINATION_DB"
        if [ $? -eq 0 ]; then
            log "rsync_db executed successfully"
        else
            log "Error executing rsync_db"
        fi

        # Creating a file with cron tasks
        transfer_cron
        upload_cron

        clear
        echo ""
        echo "Site transfer, BD, Mail, Cron - completed. Check log  $DESTINATION/transfer_logfile.log"
    fi
}

function forcefully_download_db() {
    clear
    read -p "Forcefully download DB to local server? (y/n) " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        scrap-db-local
        echo "Databases successfully dumped locally."
    else
        echo "Databases dumped locally - Action canceled."
    fi
    clear
}

function create_db_and_upload_dumps() {
    clear
    read -p "Databases will be created and corresponding dumps will be uploaded into them. Continue? (y/n) " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        create_db_on_cpanel
        upload_dump_on_cpanel
        echo "Database creation completed."
    else
        echo "Database creation - Action canceled."
    fi
    clear
}

function transfer_missing_directories() {
    clear
    read -p "Scan for missing directories? (y/n) " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        missing_domains
        echo "Missing directories scanning completed."
    else
        echo "Missing directories scanning - Action canceled."
    fi
    clear
}

function replace_paths_in_configs() {
    clear
    read -p "Replace PATHs in configs? (y/n) " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        replace_config_urls
        echo "Replacing PATHs in Configs completed."
    else
        echo "Replacing PATHs in Configs - Action canceled."
    fi
    clear
}

function manage_domains() {
    clear
    echo "1. Create domains"
    echo "2. Delete domains"
    read -p "Choose an action (1/2): " response

    case $response in
        1)
            read -p "Create domains? (y/n) " response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                create_domain
                echo "Domains creating completed."
            else
                echo "Domains creating - Action canceled."
            fi
            ;;
        2)
            read -p "Delete domains? (y/n) " response
            if [[ "$response" =~ ^[Yy]$ ]]; then
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
}

function create_mailboxes() {
    clear
    read -p "Create mailboxes? (y/n) " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        create_mailbox
        echo "Mailbox creation completed."
    else
        echo "Mailbox creation - Action canceled."
    fi
}

function delete_all_users_and_db() {
    clear
    read -p "Delete All users & db in cPanel? (y/n) " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        delete_all_db_user_cpanel
        echo "Deleting All users & db in cPanel completed."
    else
        echo "Deleting All users & db in cPanel - Action canceled."
    fi
    clear
}