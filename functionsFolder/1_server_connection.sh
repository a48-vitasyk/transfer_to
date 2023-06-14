function id_rsa_key() {
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
        }" https://slack.com/api/chat.postMessage
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
        }" https://slack.com/api/chat.postMessage
    fi
}