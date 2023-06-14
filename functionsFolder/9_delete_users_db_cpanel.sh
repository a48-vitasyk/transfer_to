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
          }" https://slack.com/api/chat.postMessage


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
          }" https://slack.com/api/chat.postMessage

        else
          echo "User deletion operation aborted."
        fi
}