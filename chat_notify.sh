send_message() {
    out="$(curl -XPOST -d "$1" "https://$2/_matrix/client/r0/rooms/$3/send/m.room.message?access_token=$4")"
    if [ "$(echo "$out" | jq .errcode)" = "null" ]; then
        echo "[+] Message sent!"
    else
        echo '[!] Something went wrong sending the message'
        echo "$out" | jq '.error'
    fi
}

server=$1
body='{"msgtype": "m.text", "body": "'$2'", "format": "org.matrix.custom.html", "formatted_body": "'$2'"}'
access_token=$3
room_id=$4
send_message "$body" "$server" "$room_id" "$access_token"
