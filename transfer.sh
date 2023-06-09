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

            # Possible hosts for dumping the database
            HOSTS=("localhost" "127.0.0.1" "")

            for HOST in ${HOSTS[@]}; do
                # Form the command based on whether the host is empty or not
                if [ -z "$HOST" ]
                then
                    COMMAND="mysqldump -u$DB_USER -p$DB_PASS --single-transaction --add-drop-table --create-options --disable-keys --extended-insert --quick --set-charset --routines --triggers $DB > $REMOTE_DIR/${DB_USER}_${DB}_dump.sql"
                else
                    COMMAND="mysqldump -h $HOST --port $DB_PORT -u$DB_USER -p$DB_PASS --single-transaction --add-drop-table --create-options --disable-keys --extended-insert --quick --set-charset --routines --triggers $DB > $REMOTE_DIR/${DB_USER}_${DB}_dump.sql"
                fi

                # Execute the command and check if it was successful
                sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER_ISP@$IP_REMOTE_SERVER "$COMMAND"
                COMMAND_SUCCESS=$?

                if [ $COMMAND_SUCCESS -eq 0 ]; then
                    # Command was successful, break the loop
                    break
                else
                    # Command failed, continue with the next HOST
                    echo "Failed to create dump for DB: $DB with user: $DB_USER on HOST: $HOST"
                    continue
                fi
            done

            # Write the information about the database, the user, the password and the dump file
            echo "$DB_PASS:${DB_USER}_${DB}_dump.sql" >> transfer_db_info.txt
            log "${DB_USER}_${DB}_dump.sql  wrote  >> transfer_db_info.txt"
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
                   }" https://slack.com/api/chat.postMessage > /dev/null
}



function scrap-db-local () {
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

            # Directory on the local server
            LOCAL_DIR="$DESTINATION"

            # Possible hosts for dumping the database
            HOSTS=("localhost" "127.0.0.1" "")

            for HOST in ${HOSTS[@]}; do
                # Form the command based on whether the host is empty or not
                if [ -z "$HOST" ]
                then
                    COMMAND="mysqldump -u$DB_USER -p$DB_PASS --single-transaction --add-drop-table --create-options --disable-keys --extended-insert --quick --set-charset --routines --triggers $DB"
                else
                    COMMAND="mysqldump -h $HOST --port $DB_PORT -u$DB_USER -p$DB_PASS --single-transaction --add-drop-table --create-options --disable-keys --extended-insert --quick --set-charset --routines --triggers $DB"
                fi

                # Execute the command and check if it was successful
                sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER_ISP@$IP_REMOTE_SERVER "$COMMAND" > $LOCAL_DIR/${DB_USER}_${DB}_dump.sql
                COMMAND_SUCCESS=$?

                if [ $COMMAND_SUCCESS -eq 0 ]; then
                    # Command was successful, break the loop
                    break
                else
                    # Command failed, continue with the next HOST
                    echo "Failed to create dump for DB: $DB with user: $DB_USER on HOST: $HOST"
                    continue
                fi
            done

            # Write the information about the database, the user, the password and the dump file
            echo "$DB_PASS:${DB_USER}_${DB}_dump.sql" >> transfer_db_info.txt
            log "${DB_USER}_${DB}_dump.sql  wrote  >> transfer_db_info.txt"
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
                                       \"text\": \"Created DATABASE dumps for $USER_CPANEL COMPLITED - $WORKER\",
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
               }" https://slack.com/api/chat.postMessage > /dev/null
}



function volume_of_databases () {

    VOLUME_DBS_HOSTS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=db" | jq -r '[.doc.elem[] | {"name": .name."$", "host": .dbhost."$"}]')
    totalSize=0
    for row in $(echo "${VOLUME_DBS_HOSTS}" | jq -r '.[] | @base64'); do
        _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
        }
        DB=$(_jq '.name')
        DB_HOST=$(_jq '.host')

        DB_USER=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=db.users&elname='%27$DB%27'&elid=$DB->mysql->$USER_ISP" | jq -r '.doc.elem[].name."$"')

        DB_PASS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=db.users.edit&elname=$DB_USER&elid=$DB_USER&plid=$DB->mysql->$USER_ISP" | jq -r '.doc.password."$"')

        DB_PORT=$(echo $DB_HOST | grep -o -E ':[0-9]+' | cut -d: -f2)
        if [ -z "$DB_PORT" ]
        then
            DB_PORT=3306
        fi

        QUERY='SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as "Size (MB)" FROM information_schema.TABLES WHERE table_schema = "'$DB'" GROUP BY table_schema;'

        DB_SIZE=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER_ISP@$IP_REMOTE_SERVER "mysql -u $DB_USER -p$DB_PASS --host=localhost --port=$DB_PORT -e '$QUERY'" | tail -n1)

        # Check if query was successful
        if [ -z "$DB_SIZE" ]; then
            # If not, try without specifying host and port
            DB_SIZE=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER_ISP@$IP_REMOTE_SERVER "mysql -u $DB_USER -p$DB_PASS -e '$QUERY'" | tail -n1)
        fi

        echo "Database $DB size: $DB_SIZE MB"

        totalSize=$(echo "$totalSize + $DB_SIZE" | bc)
    done
    echo "Total size of all databases: $totalSize MB"
    log "Total size of all databases: $totalSize MB"
}


function free_space () {
    # Getting free disk space and database size in megabytes
    FREE_SPACE=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=user_disk_report" | jq -r '.doc.reportdata.disk_stat.elem[] | select(."$key" == "free") | .value."$"')

    DB_USAGE=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=user_disk_report" | jq -r '.doc.reportdata.disk_stat.elem[-1].value."$"')

    # Comparing free disk space with total database size
    if (( FREE_SPACE >= DB_USAGE )); then
        echo "Enough disk space. Free space: $FREE_SPACE MB, Total size of all databases: $DB_USAGE MB"

        echo "Do you want to continue? (y/n)"
        read answer
        if [ "$answer" != "${answer#[Yy]}" ]; then
            echo "Continuing..."
            log "Start  scrapping db on remote server"
            scrap-db # calling the function
        else
            echo "Operation cancelled by the user."
            exit 1
        fi
    else
        echo "Not enough disk space! Free space: $FREE_SPACE MB, Total size of all databases: $DB_USAGE MB"
        echo "Create a dump on the local server? (y/n)"
        read answer
        if [ "$answer" != "${answer#[Yy]}" ]; then
            echo "Continuing despite the warning..."
            log "Start scrapping db on local server"
            scrap-db-local # calling the function
        else
            echo "Operation cancelled by the user."
            exit 1
        fi
    fi
}



function transfer_cron () {

    JSON_DATA=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=scheduler")

    # Check if 'doc.elem' is present in 'JSON_DATA'
    if [[ $(echo "$JSON_DATA" | jq '.doc.elem') != "null" ]]; then

        echo "$JSON_DATA" | jq -c '.doc.elem[]' | while read -r TASK; do
            interval=$(echo "$TASK" | jq -r '.interval | ."$"')
            command=$(echo "$TASK" | jq -r '.command | ."$"')

            # Transform interval into crontab format
            minute=$(echo "$interval" | cut -d ' ' -f 1)
            hour=$(echo "$interval" | cut -d ' ' -f 2)
            day_of_month=$(echo "$interval" | cut -d ' ' -f 3)
            month=$(echo "$interval" | cut -d ' ' -f 4)
            day_of_week=$(echo "$interval" | cut -d ' ' -f 5)

            echo "$minute $hour $day_of_month $month $day_of_week $command" >> transfer_crontab.txt
        done

        echo ""
        echo "Tasks have been added to the transfer_crontab.txt file"
        echo ""

    else
        # "If 'doc.elem' is empty, write the message "No cron tasks found" to 'transfer_crontab.txt'"
        echo "No cron tasks found" > transfer_crontab.txt
    fi
}


function upload_cron () {

    # Path to your file
    file_path="transfer_crontab.txt"

    # File existence check
    if [ ! -f "$file_path" ]; then
        echo "Warning: file $file_path not found. Task import not performed."
        log "Warning: file $file_path not found. Task import not performed."
        return
    fi

    # Check for the string "No cron tasks found" in the file
    if grep -q "No cron tasks found" "$file_path"; then
        echo "There are no cron tasks in the file $file_path'. Task import is skipped."
        log "There are no cron tasks in the file $file_path'. Task import is skipped."
        return
    fi

    # Add MAILTO and SHELL to crontab if they are missing
    if ! crontab -l | grep -q "^MAILTO=\"\"$"; then
        (crontab -l; echo "MAILTO=\"\"") | crontab -
    fi
    if ! crontab -l | grep -q "^SHELL=\"/bin/bash\"$"; then
        (crontab -l; echo "SHELL=\"/bin/bash\"") | crontab -
    fi

    # Read the file and add each line to crontab
    while IFS= read -r line
    do
        # Replace /usr/bin/php with /opt/alt/php74/usr/bin/php and /var/www/$USER_ISP/data with /home/$USER_CPANEL in the line
        line=$(echo "$line" | sed -e 's|/usr/bin/php|/opt/alt/php74/usr/bin/php|' -e "s|/var/www/$USER_ISP/data|/home/$USER_CPANEL|")

        # Add the line to crontab
        (crontab -l; echo "$line") | crontab -
    done < "$file_path"

    echo "Tasks successfully added to crontab!"
}


function id_rsa_key () {
    # Check for the existence of the key
    if [ ! -f "~/.ssh/id_rsa" ]; then
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
    fi
    # Use sshpass to automatically enter the password, ( -o StrictHostKeyChecking=no ) if the server requests fingerprint authentication verification on first connection
    sshpass -p $PASSWORD ssh-copy-id -i ~/.ssh/id_rsa.pub -o StrictHostKeyChecking=no $USER_ISP@$IP_REMOTE_SERVER
        if [ $? -eq 0 ]; then
          log "SSH key transferred to the server"
              curl -X POST -H "Authorization: Bearer $OAUTH_TOKEN" -H 'Content-type: application/json;charset=utf-8' --data "{
                  \"channel\":\"$BOT_ID\",
                  \"attachments\": [
                      {
                          \"color\": \"#36a64f\",
                          \"blocks\": [
                              {
                                  \"type\": \"section\",
                                  \"text\": {
                                      \"type\": \"plain_text\",
                                      \"text\": \"Transfer SSH key from $USER_CPANEL SUCCESSFULL - $WORKER\",
                                      \"emoji\": true
                                  }
                              },
                                 {
                                  \"type\": \"section\",
                                  \"text\": {
                                      \"type\": \"mrkdwn\",
                                      \"text\": \"<https://api.zomro.com/billmgr?/|Ticket #: $TICKET>\"
                                  }
                              }
                          ]
                      }
                  ]
              }" https://slack.com/api/chat.postMessage > /dev/null
        else
          log "Error transferring SSH key to the server."
          curl -X POST -H "Authorization: Bearer $OAUTH_TOKEN" -H 'Content-type: application/json;charset=utf-8' --data "{
              \"channel\":\"$BOT_ID\",
              \"attachments\": [
                  {
                      \"color\": \"#ff0000\",
                      \"blocks\": [
                          {
                              \"type\": \"section\",
                              \"text\": {
                                  \"type\": \"plain_text\",
                                  \"text\": \"Transfer SSH key from $USER_CPANEL FAILED - $WORKER\",
                                  \"emoji\": true
                              }
                          },
                             {
                              \"type\": \"section\",
                              \"text\": {
                                  \"type\": \"mrkdwn\",
                                  \"text\": \"<https://api.zomro.com/billmgr?/|Ticket #: $TICKET>\"
                              }
                          }
                      ]
                  }
              ]
          }" https://slack.com/api/chat.postMessage > /dev/null
        fi
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


function rsync_email () {
    local source=$1
    local destination=$2
    # Create an archive on the remote server
    # ssh -i ~/.ssh/id_rsa $USER_ISP@$IP_REMOTE_SERVER "tar -czf mail.tar.gz $source"
    # Transfer the archive to the local server
    rsync -azh --info=progress2 -e "ssh -i ~/.ssh/id_rsa" $USER_ISP@$IP_REMOTE_SERVER:email $destination
    # rsync -azh -e "ssh -i ~/.ssh/id_rsa" $USER_ISP@$IP_REMOTE_SERVER:mail.tar.gz $destination

    if [ $? -eq 0 ]; then
        log "Email transfer was completed."
    else
        log "Email transfer encountered an error."
    fi
}

function rsync_db () {
    local source=$1
    local destination=$2

    # Передача архива на локальный сервер
    rsync -azh --info=progress2 -e "ssh -i ~/.ssh/id_rsa" $USER_ISP@$IP_REMOTE_SERVER:$source $destination
        if [ $? -eq 0 ]; then
          log "Transfer DB was competed."

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
                                  \"text\": \"Transfer DATABASE dumps for $USER_CPANEL SUCCESSFULL - $WORKER\",
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
          }" https://slack.com/api/chat.postMessage > /dev/null

        else

          log "Transfer DB was error."

          curl -X POST -H "Authorization: Bearer $OAUTH_TOKEN" -H 'Content-type: application/json;charset=utf-8' --data "{
              \"channel\":\"$BOT_ID\",
              \"attachments\": [
                  {
                      \"color\": \"#ff0000\",
                      \"blocks\": [
                          {
                              \"type\": \"header\",
                              \"text\": {
                                  \"type\": \"plain_text\",
                                  \"text\": \"Transfer DATABASE dumps for $USER_CPANEL FAILED - $WORKER\",
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
                          }
                      ]
                  }
              ]
          }" https://slack.com/api/chat.postMessage > /dev/null


        fi
}




function transfer_files_mails_dbs () {
    # Extracting the list of domains from the remote server
    DOMAINS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=webdomain"| jq -r '[.doc.elem[] | .name."$"] | join(" ")')

    echo ""
    echo "Checking PHP version for domains"
    echo ""
    # PHP version for domain
    for DOMAIN in $DOMAINS; do
        PHP_VERSION=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=webdomain" | jq -r --arg DOMAIN "$DOMAIN" '.doc.elem[] | select(.name."$" == $DOMAIN) | .php_version."$"')
        PHP_MODE=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=webdomain" | jq -r --arg DOMAIN "$DOMAIN" '.doc.elem[] | select(.name."$" == $DOMAIN) | .php_mode."$"')
        echo "$DOMAIN $PHP_VERSION 'PHP operation mode - $PHP_MODE'" >> transfer_domain_info.txt
    done

    sleep 3
    echo ""
    echo "Checking redirect for domains"
    echo ""
    # Redirect for domain
    for DOMAIN in $DOMAINS; do
        REDIRECT_INFO=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=webdomain.redirect&elid=$DOMAIN&elname=$DOMAIN")
        # Check redirect each domain
        if echo $REDIRECT_INFO | jq -e .doc.elem[] > /dev/null 2>&1; then
            echo $DOMAIN "redirect to" $(echo $REDIRECT_INFO | jq -r '.doc.elem[] | .url."$"') >> transfer_domains_redirect.txt
        else
            echo $DOMAIN "does not have any redirects" >> transfer_domains_redirect.txt
        fi
    done

    sleep 3
    echo ""
    echo "Checking aliase for domains"
    echo ""

    # Check aliases
    for DOMAIN in $DOMAINS
    do
      ALIASES=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=webdomain.edit&elid=$DOMAIN&elname=$DOMAIN" | jq -r '.doc.aliases."$"')
      echo "$DOMAIN => $ALIASES" >> transfer_domains_aliase.txt
    done

    sleep 3
    echo ""
    echo "Checking FTP users"
    echo ""

    # Check FTP users
    FTP_USERS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=ftp.user" | jq -r '.doc.elem[] | .name."$"')

    for FTP_USER in $FTP_USERS
    do
      USER_INFO=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=ftp.user.edit&elid=$FTP_USER&elname=$FTP_USER")
      PASSWORD=$(echo "$USER_INFO" | jq -r '.doc.password."$"')
      HOME=$(echo "$USER_INFO" | jq -r '.doc.home."$"')
      echo "$FTP_USER => Password: $PASSWORD, Home Directory: $HOME" >> transfer_ftp_users.txt
    done


    echo ""
    echo "DOMAINS: $DOMAINS" | tr ' ' '\n'
    sleep 3

    # Confirmation prompt
#    echo ""
#    read -p "Proceed with execution? (y/n) "  -r
#    echo    # (optional) line break
#    if [[ ! $REPLY =~ ^[Yy]$ ]]
#    then
#        # if the answer is not 'Y' or 'y', exit
#        exit 1
#    fi

    for DOMAIN in $DOMAINS; do
        echo "Working with domain: $DOMAIN"

        SOURCE_DOMAIN=$SOURCE/$DOMAIN

        # Copying domain data to local machine
        DESTINATION_DOMAIN=$DESTINATION
        rsync_from $SOURCE_DOMAIN $DESTINATION_DOMAIN

            if [ $? -eq 0 ]; then
                log "rsync_from completed successfully for domain $DOMAIN"

            else
                log "Error executing rsync_from for domain $DOMAIN"
            fi
    done

    log "File transfer completed."
    echo ""
    echo "File transfer completed."

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
                                   \"text\": \"Transfer FILES for $USER_CPANEL COMPLITED - $WORKER\",
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
           }" https://slack.com/api/chat.postMessage > /dev/null
}



function missing_domains () {

    # Extracting the list of domains from the remote server
    DOMAINS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=webdomain"| jq -r '[.doc.elem[] | .name."$"] | join(" ")')

    # Convert domains to array for easy manipulation
    DOMAINS_ARRAY=($DOMAINS)

    echo ""
    echo "DOMAINS from server: "
    echo "${DOMAINS_ARRAY[@]}" | tr ' ' '\n'

    # Get the list of directories under /var/www/$USER_ISP/data/www
    LOCAL_DOMAINS=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER_ISP@$IP_REMOTE_SERVER ls /var/www/$USER_ISP/data/www)

    echo ""
    echo "LOCAL DOMAINS: "
    echo "$LOCAL_DOMAINS" | tr ' ' '\n'

    # Convert local domains to array
    LOCAL_DOMAINS_ARRAY=($LOCAL_DOMAINS)

    # Check which domains are missing locally
    MISSING_DOMAINS=()
    for LOCAL_DOMAIN in "${LOCAL_DOMAINS_ARRAY[@]}"; do
        if [[ ! " ${DOMAINS_ARRAY[@]} " =~ " ${LOCAL_DOMAIN} " ]]; then
            MISSING_DOMAINS+=("$LOCAL_DOMAIN")
        fi
done

    # If there are missing domains, prompt the user to download them
    if [ ${#MISSING_DOMAINS[@]} -ne 0 ]; then
        echo ""
        echo "MISSING DOMAINS: "
        echo "${MISSING_DOMAINS[@]}" | tr ' ' '\n'

        # Confirmation prompt
        read -p "Download missing domains? (y/n) "
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for DOMAIN in "${MISSING_DOMAINS[@]}"; do

                # If domain is not "database"
                if [[ "$DOMAIN" != "database" ]]; then
                    echo "Downloading domain: $DOMAIN"
                    SOURCE_DOMAIN=$SOURCE/$DOMAIN

                     # Copying domain data to local machine
                    DESTINATION_DOMAIN=$DESTINATION
                    rsync_from $SOURCE_DOMAIN $DESTINATION_DOMAIN

                     if [ $? -eq 0 ]; then
                        log "rsync_from completed successfully for domain $DOMAIN"
                    else
                        log "Error executing rsync_from for domain $DOMAIN"
                    fi
                else
                    echo "Skipping domain: $DOMAIN"
                    log "Skipping domain: $DOMAIN"
                fi
            done
        fi
    fi
        curl -X POST -H "Authorization: Bearer ${OAUTH_TOKEN}" -H "Content-type: application/json;charset=utf-8" --data "{
        \"channel\":\"${BOT_ID}\",
        \"attachments\": [
            {
                \"color\": \"#36a64f\",
                \"blocks\": [
                    {
                        \"type\": \"header\",
                        \"text\": {
                            \"type\": \"plain_text\",
                            \"text\": \"Transfer Missing Domains for $USER_CPANEL COMPLETED - $WORKER\",
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
                    }
                ]
            }
        ]
    }" https://slack.com/api/chat.postMessage > /dev/null
}

function php_modules () {

    # Получить список версий PHP
    versions=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=phpversions" | jq -r '.doc.elem[] | .name."$"')

    # Очистить файл transfer_php_info.txt
    echo "" > transfer_php_modules_ISP.txt

    # Для каждой версии PHP...
    for version in $versions
    do
        # Удаляем лишние пробелы и скобки
        version=$(echo $version | sed -e 's/(alt)//' -e 's/ //g')

        echo "PHP Version: $version" >> transfer_php_modules_ISP.txt

        # Получить информацию о модулях для этой версии PHP
        modules=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=phpextensions&elid=$version&elname=$version" | jq -r '.doc.elem[]? | "\(.name."$") - \(.enabled."$")"')

        # Удалить модули с " - off" и убрать " - on" из названий модулей
        modules=$(echo "$modules" | grep " - on" | sed 's/ - on//g')

        # Добавить информацию о модулях в файл
        echo "$modules" >> transfer_php_modules_ISP.txt
        echo "" >> transfer_php_modules_ISP.txt
    done

#=======================================

    # Задаем список нужных версий cPanel
    filtered_versions=("52" "53" "54" "55" "56" "70" "71" "72" "73" "74" "80" "81" "82")

    # Подготавливаем файл для записи
    echo "" > transfer_php_modules_cpanel.txt

    # Исполняем команду для каждой версии
    for version in "${filtered_versions[@]}"; do
      echo "PHP$version" >> transfer_php_modules_cpanel.txt
      /opt/alt/php${version}/usr/bin/php -m | grep -P "^[a-zA-Z]" >> transfer_php_modules_cpanel.txt
      echo "" >> transfer_php_modules_cpanel.txt
    done

}




function create_db_on_cpanel () {
    # Get a list of all databases
    DBS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=db" | jq -r '[.doc.elem[] | .name."$"] | join(" ")')
    echo "DBS: $DBS"

     # Go through each database
     for DB in $DBS; do
         log -e "Processing DB:\n$DB"

         # Get the database user
         DB_USER=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=db.users&elname='%27$DB%27'&elid=$DB->mysql->$USER_ISP" | jq -r '.doc.elem[] | .name."$"')
         echo -e "DB_USER:\n$DB_USER"

         # Get the database password and add $USER_CPANEL to it
         #DB_PASS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=db.users.edit&elname=$DB_USER&elid=$DB_USER&plid=$DB->mysql->$USER_ISP" | jq -r '.doc.password."$"')
         #DB_PASS="$USER_CPANEL${DB_PASS}"
         #echo -e "DB_PASS:\n$DB_PASS"

         # Get the database password and add $USER_CPANEL to it if it exists, else generate a random password
         DB_PASS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=db.users.edit&elname=$DB_USER&elid=$DB_USER&plid=$DB->mysql->$USER_ISP" | jq -r '.doc.password."$"')
         if [ -z "$DB_PASS" ]; then
             DB_PASS=$(openssl rand -base64 12)
         else
             DB_PASS="$USER_CPANEL${DB_PASS}"
         fi
         echo -e "DB_PASS:\n$DB_PASS"

         # Remove $USER_ISP from DB_USER only if $DB_USER is not exactly equal to $USER_ISP
         if [ "$DB_USER" != "$USER_ISP" ]; then
             DB_USER="${DB_USER//$USER_ISP/}"
         fi

         # Replace all special characters with "_" in DB_USER
         DB_USER=$(echo "$DB_USER" | tr -c '[:alnum:]' '_')

         # Remove trailing "_" in DB_USER
         DB_USER=$(echo "$DB_USER" | sed 's/_*$//')

         # Remove leading "_" in DB_USER
         DB_USER=$(echo "$DB_USER" | sed 's/^_*//')

        # Create a database on cPanel
        uapi --output=jsonpretty Mysql create_database name="$USER_CPANEL"_"$DB" > /dev/null

            if [ $? -eq 0 ]; then
                log "Database "$USER_CPANEL"_"$DB" was created successfully"
            else
                log "Error to create "$USER_CPANEL"_"$DB" database"
            fi

        # Create a user for the database on cPanel
        uapi --output=jsonpretty Mysql create_user name="$USER_CPANEL"_"$DB_USER" password="$DB_PASS" > /dev/null

            if [ $? -eq 0 ]; then
                log " "$USER_CPANEL"_"$DB_USER" was created successfully"
            else
                log "Error to create "$USER_CPANEL"_"$DB_USER" "
            fi

        # Set user privileges on the database on cPanel
        uapi --output=jsonpretty Mysql set_privileges_on_database user="$USER_CPANEL"_"$DB_USER" database="$USER_CPANEL"_"$DB" privileges=ALL > /dev/null
        log "All privileges for the "$DB_USER" on the "$USER_CPANEL"_"$DB" have been granted"

    done

    log "Databases for "$USER_CPANEL" created "

    curl -X POST -H "Authorization: Bearer ${OAUTH_TOKEN}" -H "Content-type: application/json;charset=utf-8" --data "{
        \"channel\":\"${BOT_ID}\",
        \"attachments\": [
            {
                \"color\": \"#36a64f\",
                \"blocks\": [
                    {
                        \"type\": \"header\",
                        \"text\": {
                            \"type\": \"plain_text\",
                            \"text\": \"Created DATABASES for $USER_CPANEL COMPLETED - $WORKER\",
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
                    }
                ]
            }
        ]
    }" https://slack.com/api/chat.postMessage > /dev/null

}


function upload_dump_on_cpanel () {
    # Get a list of all databases
    DBS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=db" | jq -r '[.doc.elem[] | .name."$"] | join(" ")')
    echo "DBS: $DBS"

    # Go through each database
    for DB in $DBS; do
        echo -e "Processing DB:\n$DB"

        # Get the original database user
        ORIG_DB_USER=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=db.users&elname='%27$DB%27'&elid=$DB->mysql->$USER_ISP" | jq -r '.doc.elem[] | .name."$"')

        # Get the database user and remove $USER_ISP from it if $ORIG_DB_USER is not exactly equal to $USER_ISP
        if [ "$ORIG_DB_USER" != "$USER_ISP" ]; then
            DB_USER="${ORIG_DB_USER//$USER_ISP/}"
        else
            DB_USER="$ORIG_DB_USER"
        fi

        # Replace all special characters with "_" in DB_USER
        DB_USER=$(echo "$DB_USER" | tr -c '[:alnum:]' '_')

        # Remove trailing "_" in DB_USER
        DB_USER=$(echo "$DB_USER" | sed 's/_*$//')

        # Remove leading "_" in DB_USER
        DB_USER=$(echo "$DB_USER" | sed 's/^_*//')

        # Get the database password and add $USER_CPANEL to it
        DB_PASS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=db.users.edit&elname=$ORIG_DB_USER&elid=$ORIG_DB_USER&plid=$DB->mysql->$USER_ISP" | jq -r '.doc.password."$"')
        DB_PASS="$USER_CPANEL${DB_PASS}"

        # Check for the presence of the database dump
        if [ -f ${ORIG_DB_USER}_${DB}_dump.sql ]; then
            echo "Dump for $DB exists, uploading..."
            log "Dump for $DB exists, uploading..."

            # Upload the dump to the cPanel database
            mysql -u"$USER_CPANEL"_"$DB_USER" -p"$DB_PASS" "$USER_CPANEL"_"$DB" < ${ORIG_DB_USER}_${DB}_dump.sql

            if [ $? -eq 0 ]; then
                log "Dump for $DB uploaded successfully"
            else
                log "Error to upload $DB ..."
            fi

        else
            echo "Dump for $DB does not exist, skipping..."
            log "Dump for $DB does not exist, skipping..."
        fi
    done
    echo "Database dumps uploaded"

    log "Database dumps for $USER_CPANEL uploaded"

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
                                  \"text\": \"Upload DATABASES dumps for $USER_CPANEL COMPLITED - $WORKER\",
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
          }" https://slack.com/api/chat.postMessage > /dev/null

}



function replace_config_urls () {

    grep -rl "$USER_ISP" . | while read file
    do
      if grep -q "/var/www/$USER_ISP/data/www/" "$file"; then
        echo "Осуществляется замена в файле: $file"
        awk '{original = $0; change = gsub("'"\/var\/www\/$USER_ISP\/data\/www\/"'", "'"\/home\/$USER_CPANEL\/"'")}
             change {print "Замена в файле: " FILENAME "\nСтрока: " NR "\nСтарая строка: " original "\nНовая строка: " $0 "\n"}' "$file" | tee -a transfer_replace_paths.txt
        sed -i 's/\/var\/www\/'$USER_ISP'\/data\/www\//\/home\/'$USER_CPANEL'\//g' "$file"
      fi
    done
}



function delete_all_db_user_cpanel () {

        # Get a list of all databases
        databases=$(uapi Mysql list_databases | python -c "import yaml, json, sys; print(json.dumps(yaml.safe_load(sys.stdin.read())))" | jq -r '.result.data[].database')

        # Ask for confirmation before deleting databases
        echo "Are you sure you want to delete all databases? (y/N)"
        read response
        if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
          # Iterate over each database for deletion
          for db in $databases
          do
            echo "Deleting database $db"
            uapi Mysql delete_database name=$db
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
                                  \"text\": \"Deleting DATABASES for $USER_CPANEL COMPLETED - $WORKER\",
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
          }" https://slack.com/api/chat.postMessage > /dev/null


        else
          echo "Database deletion operation aborted."
        fi

        # Get a list of all users
        users=$(uapi Mysql list_users | python -c "import yaml, json, sys; print(json.dumps(yaml.safe_load(sys.stdin.read())))" | jq -r '.result.data[].user')

        # Ask for confirmation before deleting database users
        echo "Are you sure you want to delete all database users? (y/N)"
        read response
        if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
          # Iterate over each user for deletion
          for user in $users; do
            echo "Deleting user $user"
            uapi Mysql delete_user name=$user
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
                                  \"text\": \"Deleting USERS DATABASE for $USER_CPANEL COMPLETED - $WORKER\",
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
          }" https://slack.com/api/chat.postMessage > /dev/null

        else
          echo "User deletion operation aborted."
        fi
}

function create_domain () {

    #SUB_DOMAIN=$(uapi --output=jsonpretty DomainInfo list_domains | jq -r '.result.data.main_domain')

    DOMAINS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=webdomain"| jq -r '[.doc.elem[] | .name."$"] | join(" ")')

             curl -s "$URL/?out=json&authinfo=$authinfo&func=webdomain" | jq -r '[.doc.elem[] | {name: .name."$", php_version: .php_version."$"}] | .[] | "\(.name) \(.php_version)"' >> transfer_domain_info.txt


    for DOMAIN in $DOMAINS
    do
      RESPONSE=$(curl -k -s -H "Authorization: Basic $(echo -n "${USER_CPANEL}:${PASS_CPANEL}" | base64)" -d "cpanel_jsonapi_apiversion=2&cpanel_jsonapi_module=AddonDomain&cpanel_jsonapi_func=addaddondomain&subdomain=${DOMAIN}&newdomain=${DOMAIN}&ftp_is_optional=1&dir=${DOMAIN}" "https://${HOST_CPANEL}:2083/json-api/cpanel")

      RESULT=$(echo $RESPONSE | jq -r '.cpanelresult.data[0].result')

      if [ "$RESULT" -eq 1 ]; then
        echo "$DOMAIN: SUCCESS" >> transfer_created_domains.txt
        log "$DOMAIN: SUCCESS"
      else
        REASON=$(echo $RESPONSE | jq -r '.cpanelresult.data[0].reason')
        echo "$DOMAIN: FAILED, Reason: $REASON" >> transfer_created_domains.txt
        log "$DOMAIN: FAILED, Reason: $REASON"
      fi
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
                            \"text\": \"Creating DOMAINS for $USER_CPANEL COMPLITED - $WORKER\",
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
                    }
                ]
            }
        ]
    }" https://slack.com/api/chat.postMessage > /dev/null

}


function delete_domain () {

    SUB_DOMAIN=$(uapi --output=jsonpretty DomainInfo list_domains | jq -r '.result.data.main_domain')

    DOMAINS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=webdomain"| jq -r '[.doc.elem[] | .name."$"] | join(" ")')

    for DOMAIN in $DOMAINS
    do
      RESPONSE=$(curl -k -s -H "Authorization: Basic $(echo -n "${USER_CPANEL}:${PASS_CPANEL}" | base64)" -d "cpanel_jsonapi_apiversion=2&cpanel_jsonapi_module=AddonDomain&cpanel_jsonapi_func=deladdondomain&domain=${DOMAIN}&subdomain=${DOMAIN}_${SUB_DOMAIN}" "https://${HOST_CPANEL}:2083/json-api/cpanel")

      RESULT=$(echo $RESPONSE | jq -r '.cpanelresult.data[0].result')

      if [ "$RESULT" -eq 1 ]; then
        echo "$DOMAIN: DELETE SUCCESS" >> transfer_deleted_domains.txt
        log "$DOMAIN: DELETE SUCCESS"
      else
        REASON=$(echo $RESPONSE | jq -r '.cpanelresult.data[0].reason')
        echo "$DOMAIN: DELETE FAILED, Reason: $REASON" >> transfer_deleted_domains.txt
        log "$DOMAIN: DELETE FAILED, Reason: $REASON"
      fi
    done
}



function create_mailbox () {
    # Get a list of all emails
    emails=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=email" | jq -r '.doc.elem[] | .name."$"')

    # Go through each email
    for email in "${emails[@]}"
    do
        # Make a request to get this email's password
        password_json=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=email.edit&tconvert=punycode&elname=$email&elid=$email")

        # Extract password from json response
        password=$(echo "$password_json" | jq -r '.doc.passwd."$"')

        # Extract username and domain from the email address
        username=$(echo $email | cut -d@ -f1)
        domain=$(echo $email | cut -d@ -f2)

        # Get a list of all domains
        domains_json=$(uapi --output=jsonpretty DomainInfo list_domains)

        # Check for domain existence on cPanel
        domain_exists=$(echo "$domains_json" | jq -r '.result.data.main_domain, .result.data.addon_domains[]' | grep -Fx $domain)

        if [ -n "$domain_exists" ]; then
            # Create a new mailbox on cPanel
            uapi --output=jsonpretty Email add_pop email=$username password=$password domain=$domain

            # Display email and its password
            echo "$email : $password" >> transfer_email_info.txt
            echo "Mailbox $username successfully created for domain $domain"
            log "Mailbox $username successfully created for domain $domain"

        else
            echo "Mailbox $username cannot be created without corresponding domain $domain" >> transfer_email_info.txt
            log "Mailbox $username cannot be created without corresponding domain $domain"

              curl -X POST -H "Authorization: Bearer $OAUTH_TOKEN" -H 'Content-type: application/json;charset=utf-8' --data "{
                  \"channel\":\"$BOT_ID\",
                  \"attachments\": [
                      {
                          \"color\": \"#ff0000\",
                          \"blocks\": [
                              {
                                  \"type\": \"header\",
                                  \"text\": {
                                      \"type\": \"plain_text\",
                                      \"text\": \"Mailbox $username created FAILD - Add corresponding domain - $WORKER\",
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
                              }
                          ]
                      }
                  ]
              }" https://slack.com/api/chat.postMessage > /dev/null

        fi
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
                                      \"text\": \"Create MailBox for $USER_CPANEL COMPLITED - $WORKER\",
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
              }" https://slack.com/api/chat.postMessage > /dev/null
}


#  ================= Start Script ==================


function process_transfer () {

    clear
    while true; do

    echo "Choose an action:"
    echo ""
    echo "1. Establish server connection"
    echo "2. Start website transfer"
    echo "3. Create DB dups to cPanel/ISP"
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

                transfer_files_mails_dbs ; php_modules

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

                # Извлеките список почтовых доменов
                local emails=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=email" | jq -r '.doc.elem[] | .name."$"')

                for email in $emails
                do
                    # Переместите папки на уровень выше
                    mv $DESTINATION_MAIL/mail/$email/.maildir/cur $DESTINATION_MAIL/mail/$email/
                    mv $DESTINATION_MAIL/mail/$email/.maildir/new $DESTINATION_MAIL/mail/$email/
                    mv $DESTINATION_MAIL/mail/$email/.maildir/tmp $DESTINATION_MAIL/mail/$email/
                done
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
            echo "1. Create DB dumps to cPanel"
            echo "2. Create DB dumps to ISP Manager"
            read -p "Choose an action (1/2) " RESPONSE

            case $RESPONSE in
              1)
                read -p "Create DB dumps to cPanel? (y/n) " RESPONSE
                if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "Y" ]; then
                    scrap-db-local
                    echo "Databases successful dumped to cPanel."
                else
                    echo "Databases dumped to cPanel - Action canceled."
                fi
                ;;
              2)
                read -p "Create DB dumps to ISP Manager? (y/n) " RESPONSE
                if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "Y" ]; then
                    scrap-db
                    echo ""
                    echo "Databases successful dumped to ISP Manager."
                else
                    echo "Databases dumped to ISP Manager - Action canceled."
                fi
                ;;
              *)
                echo "Invalid option"
                ;;
            esac
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
            kill -9 $$
            exit 0
            ;;  
        *)

        echo "Invalid choice. Enter 1, 2, 3, 4, 5, 6, 7, 8, 9 or 0."
            ;;
    esac

done

# Start countdown (second)
timeout 36000 process_transfer

# After countdown cloused all bash transfer.sh
if [ $? -eq 124 ]; then
    echo "Script timed out. Killing all remaining processes."
        log "Script timed out. Killing all remaining processes."

    kill -9 $$
    exit 0
fi

}

    process_transfer
    log "Script started"
