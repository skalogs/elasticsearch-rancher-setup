#!/usr/bin/env bash
set -x

RANCHER_BASEURL=rancher-metadata.rancher.internal/latest

if [ -z "${SERVICE_ELASTICSEARCH_USERNAME}"]; then
  ES_AUTH=""
else
  ES_AUTH="${SERVICE_ELASTICSEARCH_USERNAME}:${SERVICE_ELASTICSEARCH_PASSWORD}@"
fi
ES_URL=http://${ES_AUTH}${SERVICE_ELASTICSEARCH_HOST}:${SERVICE_ELASTICSEARCH_PORT}

function checkElasticsearch {
    a="`curl ${ES_URL}/_cluster/health &> /dev/null; echo $?`"
    while  [ $a -ne 0 ];
    do
        a="`curl ${ES_URL}/_cluster/health &> /dev/null; echo $?`"
        sleep 1
    done
}

function retryHttp {
    httpWord=$1
    url=$2
    content=$3
    curlCommand="curl -X${httpWord} ${url} --compressed -H 'Content-Type: application/json;charset=UTF-8' --write-out %{http_code} --output /dev/null -d @${content}"
    status=$(eval $curlCommand)
    while  [ $status -ne 200 ] ;
    do
        status=$(eval $curlCommand)
        sleep 1
    done
}

checkElasticsearch

mkdir /elasticsearch

#get dynamic templates
response=$(curl --write-out %{http_code} --silent --output /dev/null http://${RANCHER_BASEURL}/self/service/metadata/templates)
if [ "$response" -eq 200 ]
then
    curl http://${RANCHER_BASEURL}/self/service/metadata/templates > /elasticsearch/templates.json
    mkdir -p /elasticsearch/templates
    jq -rc '.[]' /elasticsearch/templates.json | while IFS='' read -r objectConfig ; do
      name=$(echo "$objectConfig" | jq -r .name)
      config=$(echo "$objectConfig" | jq -r .value)
      if [ "$name" = "null"] && [ "$config" = "null"]; then
        echo "templateName or template is null, ignoring this entry..."
      else
        echo Posting index template $name
        echo "$config" > /elasticsearch/templates/$name.json
        retryHttp PUT "${ES_URL}/_template/$name" /elasticsearch/templates/${name}.json
      fi
    done
fi

#configure repositories
response=$(curl --write-out %{http_code} --silent --output /dev/null http://${RANCHER_BASEURL}/self/service/metadata/repositories)
if [ "$response" -eq 200 ]
then
    curl http://${RANCHER_BASEURL}/self/service/metadata/repositories > /elasticsearch/repositories.json
    mkdir -p /elasticsearch/repositories
    jq -rc '.[]' /elasticsearch/repositories.json | while IFS='' read -r objectConfig ; do
      name=$(echo "$objectConfig" | jq -r .name)
      config=$(echo "$objectConfig" | jq -r .value)
      if [ "$name" = "null"] && [ "$config" = "null"]; then
        echo "repositoryName or repository is null, ignoring this entry..."
      else
        echo Posting repository $name config
        echo "$config" > /elasticsearch/templates/$name.json
        retryHttp PUT "${ES_URL}/_snapshot/${name}?pretty" /elasticsearch/templates/${name}.json
      fi
    done
fi

#apply license
response=$(curl --write-out %{http_code} --silent --output /dev/null http://${RANCHER_BASEURL}/self/service/metadata/license)
if [ "$response" -eq 200 ]
then
    echo Get license
    curl http://${RANCHER_BASEURL}/self/service/metadata/license > /elasticsearch/license.json

    echo Posting license
    retryHttp PUT "${ES_URL}/_xpack/license?acknowledge=true" /elasticsearch/license.json
fi
