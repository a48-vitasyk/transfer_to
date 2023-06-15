function create_domain() {
  #SUB_DOMAIN=$(uapi --output=jsonpretty DomainInfo list_domains | jq -r '.result.data.main_domain')
    DOMAINS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=webdomain" | jq -r '[.doc.elem[] | .name."$"] | join(" ")')

    for DOMAIN in $DOMAINS; do
        RESPONSE=$(curl -k -s -H "Authorization: Basic $(echo -n "${USER_CPANEL}:${PASS_CPANEL}" | base64)" -d "cpanel_jsonapi_apiversion=2&cpanel_jsonapi_module=AddonDomain&cpanel_jsonapi_func=addaddondomain&subdomain=${DOMAIN}&newdomain=${DOMAIN}&ftp_is_optional=1&dir=${DOMAIN}" "https://${HOST_CPANEL}:2083/json-api/cpanel")

        RESULT=$(echo $RESPONSE | jq -r '.cpanelresult.data[0].result')

        if [ "$RESULT" -eq 1 ]; then
            echo "$DOMAIN: SUCCESS" >> created_domains.txt
            log "$DOMAIN: SUCCESS"
        else
            REASON=$(echo $RESPONSE | jq -r '.cpanelresult.data[0].reason')
            echo "$DOMAIN: FAILED, Reason: $REASON" >> created_domains.txt
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
    }" https://slack.com/api/chat.postMessage
}

function delete_domain () {

    SUB_DOMAIN=$(uapi --output=jsonpretty DomainInfo list_domains | jq -r '.result.data.main_domain')

    DOMAINS=$(curl -s "$URL/?out=json&authinfo=$authinfo&func=webdomain"| jq -r '[.doc.elem[] | .name."$"] | join(" ")')

    for DOMAIN in $DOMAINS
    do
      RESPONSE=$(curl -k -s -H "Authorization: Basic $(echo -n "${USER_CPANEL}:${PASS_CPANEL}" | base64)" -d "cpanel_jsonapi_apiversion=2&cpanel_jsonapi_module=AddonDomain&cpanel_jsonapi_func=deladdondomain&domain=${DOMAIN}&subdomain=${DOMAIN}_${SUB_DOMAIN}" "https://${HOST_CPANEL}:2083/json-api/cpanel")

      RESULT=$(echo $RESPONSE | jq -r '.cpanelresult.data[0].result')

      if [ "$RESULT" -eq 1 ]; then
        echo "$DOMAIN: DELETE SUCCESS" >> deleted_domains.txt
        log "$DOMAIN: DELETE SUCCESS"
      else
        REASON=$(echo $RESPONSE | jq -r '.cpanelresult.data[0].reason')
        echo "$DOMAIN: DELETE FAILED, Reason: $REASON" >> deleted_domains.txt
        log "$DOMAIN: DELETE FAILED, Reason: $REASON"
      fi
    done
}