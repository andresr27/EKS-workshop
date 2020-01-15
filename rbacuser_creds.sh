export AWS_SECRET_ACCESS_KEY=$(cat /tmp/create_output.json | jq '.AccessKey.SecretAccessKey')
export AWS_ACCESS_KEY_ID=$(cat /tmp/create_output.json | jq '.AccessKey.AccessKeyId')
