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
    }" https://slack.com/api/chat.postMessage
}