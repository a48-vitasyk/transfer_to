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

         # Remove $USER_ISP from DB_USER
         DB_USER="${DB_USER//$USER_ISP/}"

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
    }" https://slack.com/api/chat.postMessage

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

        # Get the database user and remove $USER_ISP from it
        DB_USER="${ORIG_DB_USER//$USER_ISP/}"

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
          }" https://slack.com/api/chat.postMessage

}