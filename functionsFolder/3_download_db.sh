function scrap-db-local() {
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
        if [ -z "$DB_PORT" ]; then
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

            # Dump the database on the remote server and save it on the local server
            sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER_ISP@$IP_REMOTE_SERVER "mysqldump -h 127.0.0.1 --port $DB_PORT -u$DB_USER -p$DB_PASS $DB" > $LOCAL_DIR/${DB_USER}_${DB}_dump.sql

            # Check if dump was successful
            if [ $? -ne 0 ]; then
                # If not, try without specifying host and port
                sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER_ISP@$IP_REMOTE_SERVER "mysqldump -u$DB_USER -p$DB_PASS $DB" > $REMOTE_DIR/${DB_USER}_${DB}_dump.sql
            fi

            # Write the information about the database, the user, the password and the dump file
            echo "$DB_PASS:${DB_USER}_${DB}_dump.sql" >> db_info.txt
            log "${DB_USER}_${DB}_dump.sql wrote  >> db_info.txt"
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
    }" https://slack.com/api/chat.postMessage
}