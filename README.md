# NGINX App Protect DoS ELK Dashboards
A community supported repo for NGINX App Protect Denial of Service dashboards on the ELK stack.

<img src="images/dashboard1.png" width="800px"/>

## How does it work?
ELK stands for Elasticsearch, Logstash, and Kibana. Logstash receives logs from NGINX App Protect DoS, normalizes them and stores them in the Elasticsearch index. Kibana allows you to visualize and navigate through logs using purpose built dashboards.

## Requirements
- The installation instructions assume you are using a bash or zsh shell. The [Docker](https://docker.com), [docker-compose](https://docs.docker.com/compose/) and [jq](https://stedolan.github.io/jq/) packages are also assumed to be installed.

- The provided Kibana dashboards require a minimum version of 8.11.1. If you are using the provided [docker-compose.yaml](docker-compose.yaml) file, this version requirement is met.

- In `docker-compose.yaml`, the subnet configuration is added in order to override the ip assignment from the Docker default subnet, i.e 172.18.x.x/16. 
```
...
networks:
  default:
    ipam:
      driver: default
      config:
        - subnet: 172.33.0.0/16
```
- In case there is an error creating the docker network, restart docker: `systemctl restart docker`.

- The ELK stack docker container will likely exceed the default host's virtual memory system limits. Use [these directions](https://www.elastic.co/guide/en/elasticsearch/reference/5.0/vm-max-map-count.html#vm-max-map-count) to increase this limit on the docker host machine. If you do not, the ELK container will continually restart itself and never fully initialize.

## Installation Overview
It is assumed you will be running ELK using the Quick Start directions below. The template in `logstash/conf.d` will create a new Logstash pipeline to ingest logs and store them in Elasticsearch. If you use the supplied `docker-compose.yaml`, this template will be copied into the docker container instance for you. Once the DoS logs are being ingested into the Elasticsearch index, you will need to import files from the [kibana](kibana/) folder to create all necessary objects including the index pattern, visualization and dashboards.


### Deploying ELK Stack
1. Use docker-compose to deploy your own ELK stack.

```shell
docker-compose -f docker-compose.yaml up -d
```

2. Verify the installation by logging into Kibana via a browser at `http://< your container host>:5601/`

**NOTE:**
- It assumed that your current working directory is `nap-dos-elk-dashboards`.
- The `logstash` folder will be created in the working directory.
- The `logstash/conf.d` folder is mapped to `/etc/logstash/conf.d` in the ELK container.

3. Open a *new* terminal window and ssh into the Elasticsearch container:

```shell
docker exec -it nap-dos-elk-dashboards_elasticsearch_1 /bin/bash
```

4. From inside the container, stop the `logstash` process:

```shell
service logstash stop
```

5. Install Logstash plugins :

```shell
/opt/logstash/bin/logstash-plugin install logstash-output-syslog
/opt/logstash/bin/logstash-plugin install logstash-input-syslog
/opt/logstash/bin/logstash-plugin install logstash-input-tcp
/opt/logstash/bin/logstash-plugin install logstash-input-udp
```

6. Print the contents of the Logstash configuration file to ensure it exists:

```shell
cat /etc/logstash/conf.d/apdos-logstash.conf
```

7. In your *original* terminal window (outside the container), create the Elasticsearch index with the following cURL command:

```shell
curl -XPUT "http://localhost:9200/app-protect-dos-logs"  -H "Content-Type: application/json" -d  @apdos_mapping.json
```

**NOTE:**
In case there is error in this step, it may indicate that the `app-protect-dos-logs` index already exists from a previous Kibana installation, or has been created automatically by Logstash processing incoming App Protect DoS messages. If so, you will need to delete the index with the following cURL command:

```shell
curl -XDELETE http://localhost:9200/app-protect-dos-logs
```

To verify that `app-protect-dos-logs` index has been deleted:

```shell
curl -XGET "http://localhost:9200/_cat/indices"
```

The result should not include an `app-protect-dos-logs` index. Then, re-attempt to create the index using the instructions in the step above.

8. Update mapping with geo fields:

```shell
curl -XPOST "http://localhost:9200/app-protect-dos-logs/_mapping"  -H "Content-Type: application/json" -d  @apdos_geo_mapping.json
```

9. Import dashboards to Kibana through the UI (Kibana -> Management -> Saved Objects) or alternatively, use API call below:

```shell

KIBANA_CONTAINER_URL=http://localhost:5601

jq -s . kibana/apdos-dashboard.ndjson | jq '{"objects": . }' | \
curl -k --location --request POST "$KIBANA_CONTAINER_URL/api/kibana/dashboards/import" \
    --header 'kbn-xsrf: true' \
    --header 'Content-Type: text/plain' -d @- \
    | jq

```

10. From your terminal window *inside* the container, start Logstash:

```shell
service logstash start
```

### NGINX App Protect DoS Configuration
NGINX App Protect DoS configuration directives as should appear in your `nginx.conf`. You will need to replace `ip_kibana` in the snippet below with the hostname of the server hosting your ELK Docker container:

```
http {
    log_format log_dos ', vs_name_al=$app_protect_dos_vs_name, ip=$remote_addr, tls_fp=$app_protect_dos_tls_fp, outcome=$app_protect_dos_outcome, reason=$app_protect_dos_outcome_reason, ip_tls=$remote_addr:$app_protect_dos_tls_fp, ';
    ...
    server {
       ...

       app_protect_dos_security_log_enable on;
       app_protect_dos_security_log "/etc/app_protect_dos/log-default.json" syslog:server=ip_kibana:5261;


       location / {
           app_protect_dos_enable       on;
           set $loggable '0';
           access_log syslog:server=ip_kibana:5561 log_dos if=$loggable;

        ...   
       }
       
    }
    ...
}
```

**NOTE:**
The Logstash listener in this solution is configured to listen for TCP syslog messages on port `5261` and UDP port `5561`. Kibana and Elasticsearch are using TCP ports `9200`, `5601` respectively.
These ports must be opened on your firewall for TCP/UDP accordingly.


## Distinguishing services in the case of multiple protected objects (vss)

Using the dashboard filter:
As an example, for protected object name "example.com", the filter should be as follows:
`vs_name_al : "example.com/"  or vs_name : "example.com/"`

**NOTE:**
`vs_name_al` and `vs_name` must be both at dashboard filter level, and be connected with: "or".

## Installing Both App Protect WAF and App Protect DoS Dashboards

Both the [App Protect WAF](https://github.com/f5devcentral/f5-waf-elk-dashboards) and DoS Dashboards (this repo) can work in parallel on the same ELK instance. However some preparation is necessary to ensure they will run successfully in parallel with each other.

1. Clone the [f5-waf-elk-dashboards](https://github.com/f5devcentral/f5-waf-elk-dashboards) and App Protect DoS Dashboards (this repo) using the following commands:

```shell
git clone https://github.com/f5devcentral/f5-waf-elk-dashboards.git
git clone https://github.com/f5devcentral/nap-dos-elk-dashboards.git
```

2. Copy the `apdos-logstash.conf` file to the `f5-waf-elk-dashboards` working directory:
```shell
cp nap-dos-elk-dashboards/logstash/conf.d/apdos-logstash.conf f5-waf-elk-dashboards/logstash/conf.d/
```

3. Create a `f5-waf-elk-dashboards/logstash/pipelines.yml` file with the following contents:
```yaml
- pipeline.id: napwaf
  path.config: "/opt/logstash/config/30-waf-logs-full-logstash.conf"

- pipeline.id: napdos
  path.config: "/opt/logstash/config/apdos-logstash.conf"
```

4. The `f5-waf-elk-dashboards/docker-compose.yaml` needs to be modified to accommodate 3 necessary changes: the version of the ELK container image used, additional syslog ports are required, and Logstash's [Multiple Pipelines](https://www.elastic.co/blog/logstash-multiple-pipelines) feature needs to be used in order to isolate the message flows. A properly modified `docker-compose.yaml` will look like this:

```yaml
version: "2.4"
services:
  elasticsearch:
    image: sebp/elk:793
    restart: always
    volumes:
      - ./logstash/pipelines.yml:/opt/logstash/config/pipelines.yml:ro
      - ./logstash/conf.d/30-waf-logs-full-logstash.conf:/opt/logstash/config/30-waf-logs-full-logstash.conf:ro
      - ./logstash/conf.d/apdos-logstash.conf:/opt/logstash/config/apdos-logstash.conf:ro
      - elk:/var/lib/elasticsearch
    ports:
      - 9200:9200/tcp
      - 5601:5601/tcp
      - 5144:5144/tcp
      - 5261:5261/tcp
      - 5561:5561/udp
volumes:
  elk:

```

5. Change to the `f5-waf-elk-dashboards` directory:
``` shell
cd f5-waf-elk-dashboards
```

6. Follow the [Deploying ELK Stack](https://github.com/f5devcentral/f5-waf-elk-dashboards#deploying-elk-stack) instructions in the f5-waf-elk-dashboards README document, then advance to step 7 in this guide when complete.

7. Change to the `nap-dos-elk-dashboards` directory:
``` shell
cd ../nap-dos-elk-dashboards
```

8. Open a *new* terminal window and ssh into the Elasticsearch container:

```shell
docker exec -it f5-waf-elk-dashboards_elasticsearch_1 /bin/bash
```

9. Follow the [Deploying ELK Stack](#deploying-elk-stack) instructions starting at step 4.
