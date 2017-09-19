# elasticsearch-rancher-setup

This utility container is here to push specific configuration to elasticsearch from [rancher-compose.yml's metadata](rancher-metadata/rancher-compose.yml):
 - elasticsearch templates
 - repository configuration
 - elasticsearch license

Elasticsearch license can be pasted as is.

Elasticsearch templates and repository configuration rely on a custom structure supporting multiple entries (a structured json array):
```json
[
  {
    "name": "mytemplate",
    "value": #Paste your template or repository config here
  }
]
```

All these configurations option are optional.
