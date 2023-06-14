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
            echo "$email : $password" >> email_info.txt
            echo "Mailbox $username successfully created for domain $domain"
            log "Mailbox $username successfully created for domain $domain"

        else
            echo "Mailbox $username cannot be created without corresponding domain $domain" >> email_info.txt
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
              }" https://slack.com/api/chat.postMessage

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
              }" https://slack.com/api/chat.postMessage
}