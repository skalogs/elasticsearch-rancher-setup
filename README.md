# elasticsearch-rancher-setup

This utility container is here to push :
 - elasticsearch templates
 - repository configuration
 - elasticsearch license

The content of each of these is fetch from [rancher-compose.yml's metadata](rancher-metadata/rancher-compose.yml).

The content of elasticsearch license can be pasted as is.
The content of elasticsearch templates and repository configuration rely on a custom structure (a structured json array):
```json
[
  {
    "name": "mytemplate",
    "value": #Paste your template or repository config here
  }
]
```
