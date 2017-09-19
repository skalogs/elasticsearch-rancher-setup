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
    a="`curl -XGET ${ES_URL}/_cluster/health &> /dev/null; echo $?`"
    while  [ $a -ne 0 ];
    do
        a="`curl -XGET ${ES_URL}/_cluster/health &> /dev/null; echo $?`"
        sleep 1
    done
}

function retryHttp {
    status=$($1)
    while  [ $status -ne 200 ];
    do
        status=$($1)
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
    jq -rc '.[]' /elasticsearch/templates.json | while IFS='' read templateConfig ; do
      templateName=$(echo $templateConfig | jq .name)
      template=$(echo $templateConfig | jq .value)
      if [ "$templateName" = "null"] && [ "$template" = "null"]; then
        echo "templateName or template is null, ignoring this entry..."
      else
        echo Posting index template $templateName
        retryHttp "curl -XPUT ${ES_URL}/_template/$templateName --write-out %{http_code} --output /dev/null -d \"${template}\""
      fi
    done
fi

#configure repositories
response=$(curl --write-out %{http_code} --silent --output /dev/null http://${RANCHER_BASEURL}/self/service/metadata/repositories)
if [ "$response" -eq 200 ]
then
    curl http://${RANCHER_BASEURL}/self/service/metadata/repositories > /elasticsearch/repositories.json
    jq -rc '.[]' /elasticsearch/repositories.json | while IFS='' read repositoryConfig ; do
      repositoryName=$(echo $repositoryConfig | jq .name)
      repository=$(echo $repositoryConfig | jq .value)
      if [ "$repositoryName" = "null"] && [ "$repository" = "null"]; then
        echo "repositoryName or repository is null, ignoring this entry..."
      else
        echo Posting repository $repositoryName config
        retryHttp "curl -XPUT ${ES_URL}/_snapshot/${repositoryName}?pretty --write-out %{http_code} --output /dev/null -d \"${repository}\""
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
    retryHttp "curl -XPUT ${ES_URL}/_xpack/license?acknowledge=true --write-out %{http_code} --output /dev/null -d @/elasticsearch/license.json"
fi
