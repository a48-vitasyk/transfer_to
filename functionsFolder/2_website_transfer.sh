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

        DB_SIZE=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER_ISP@$IP_REMOTE_SERVER "mysql -u $DB_USER -p$DB_PASS --host=127.0.0.1 --port=$DB_PORT -e '$QUERY'" | tail -n1)

        # Check if query was successful
        if [ $? -ne 0 ]; then
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

function transfer_files_mails_dbs () {
    # Extracting the list of domains from the remote server
    DOMAINS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=webdomain"| jq -r '[.doc.elem[] | .name."$"] | join(" ")')
    echo ""
    echo "DOMAINS: $DOMAINS" | tr ' ' '\n'

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
           }" https://slack.com/api/chat.postMessage
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
          }" https://slack.com/api/chat.postMessage

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
          }" https://slack.com/api/chat.postMessage


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

            echo "$minute $hour $day_of_month $month $day_of_week $command" >> crontab.txt
        done

        echo ""
        echo "Tasks have been added to the crontab.txt file"
        echo ""

    else
        # "If 'doc.elem' is empty, write the message "No cron tasks found" to 'crontab.txt'"
        echo "No cron tasks found" > crontab.txt
    fi
}

function upload_cron () {

    # Path to your file
    file_path="crontab.txt"

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