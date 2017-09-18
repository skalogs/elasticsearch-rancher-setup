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
response=$(curl --write-out %{http_code} --silent --output /dev/null http://${RANCHER_BASEURL}/self/service/metadata/template)
if [ "$response" -eq 200 ]
then
    mkdir -p /elasticsearch/templates
    for template in `curl http://${RANCHER_BASEURL}/self/service/metadata/template` ; do
        templateName=`basename ${template}`
        echo Get index template $templateName from rancher-compose
        curl http://${RANCHER_BASEURL}/self/service/metadata/template/$templateName > /elasticsearch/templates/$templateName.json
        echo Posting index template $templateName
        retryHttp "curl -XPUT ${ES_URL}/_template/$templateName --write-out %{http_code} --output /dev/null -d @/elasticsearch/templates/$templateName.json"
    done
fi

#configure repositories
response=$(curl --write-out %{http_code} --silent --output /dev/null http://${RANCHER_BASEURL}/self/service/metadata/repositories)
if [ "$response" -eq 200 ]
then
    mkdir -p /elasticsearch/repositories
    for repository in `curl http://${RANCHER_BASEURL}/self/service/metadata/repositories` ; do
      repositoryName=`basename ${repository}`
      echo Get repository $repositoryName from rancher-compose
      curl http://${RANCHER_BASEURL}/self/service/metadata/repositories/$repositoryName > /elasticsearch/repositories/$repositoryName.json
      echo Posting repository $repositoryName config
      retryHttp "curl -XPUT ${ES_URL}/_snapshot/${repositoryName}?pretty --write-out %{http_code} --output /dev/null -d @/elasticsearch/repositories/$repositoryName.json"
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
