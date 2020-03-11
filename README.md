Kong
=====

This role installs and configures Kong.

Please refer to [Kong documentation](https://getkong.org/docs/) for further
information on Routes, Services, Consumer and Plugins configuration.

> *Breaking Changes:*
>
>     -  new `kong_route_config` variable introduced to decouple service and routes config previously in `kong_service_config`
>     -  structure of `kong_service_config` updated (Breaking change)
>
> For the last version without breaking changes above please use tag [v1.9](https://github.com/wunzeco/ansible-kong/tree/v1.9)

> *WARNING:*
>
>     -  Support for v0.12.x and earlier deprecated and will be removed SOON!!


## Install Kong

```
- hosts: konghost

  vars:
    kong_version: 0.13.1
    kong_cassandra_host: <my_cassandra_ip_or_fqdn>
    ## OR for postgres backend
    ## kong_database: postgres
    ## kong_pg_host: <my_pg_ip_or_fqdn>

  roles:
    - o2-priority.kong
```


## Add/Update/Delete kong objects

```
- hosts: my-kong-host

  vars:
    kong_version: 0.13.1
    kong_use_old_config_format: false

  roles:
    #*************************#
    #    SERVICES & ROUTES    #
    #*************************#
    - role: ansible-kong            ## ADD/UPDATE service obj for svcOne service
      kong_task: service
      kong_service_config:
        name: svcOne
        url: "https://service-upstream.ogonna.com/svcOne/api"
    - role: ansible-kong            ## ADD route obj for svcOne
      kong_task: route
      kong_route_config:
        name: svcOneRoute1
        service: svcOne
        paths: [ "/svcOne" ]
        hosts: [ "og.com", "ab.com" ]
    - role: ansible-kong            ## ADD route obj for svcOne
      kong_task: route
      kong_route_config:
        name: svcOneRoute2
        service: svcOne
        paths: [ "/svcOnePlus" ]
        methods: [ "GET", "POST", "PUT" ]
    - role: ansible-kong            ## DELETE service obj for svcThree
      kong_task: service
      kong_delete_service_obj: true
      kong_service_config:
        name: svcThree
    #*************************#
    #    UPSTREAM & TARGETS   #
    #*************************#
    - role: ansible-kong            ## ADD/UPDATE upstream obj for svcOne upstream
      kong_task: upstream
      kong_upstream_config:
        name: upstreamOne
        slots: 1000
    - role: ansible-kong            ## ADD target obj for upstreamOne
      kong_task: target
      kong_target_config:
        upstream: upstreamOne
        target: targetOne
        weight: 200
    - role: ansible-kong            ## DELETE upstreamOne with all targets
      kong_task: upstream
      kong_delete_upstream_obj: true
      kong_upstream_config:
        name: upstreamOne
    #*****************#
    #    CONSUMERS    #
    #*****************#
    - role: ansible-kong            ## ADD/UPDATE consumer obj for consumerOne
      kong_use_old_config_format: false
      kong_task: consumer
      kong_consumer_config:
        username: consumerOne
        custom_id: con-1111
    - role: ansible-kong            ## DELETE consumer obj for consumerTwo
      kong_use_old_config_format: false
      kong_task: consumer
      kong_consumer_config:
        username: consumerTwo
      kong_delete_consumer_obj: true
    - role: ansible-kong            ## ADD/UPDATE consumer obj for consumerThree with plugin configs
      kong_use_old_config_format: false
      kong_task: consumer
      kong_consumer_config:
        username: consumerThree
        custom_id: con-3333
        plugins:
          - name: acl
            parameters:
              groups: [ svcOne-user-group ]
          - name: key-auth
            parameters:
              key: "e2f599f74fc4479681e6586a1e644768"
          - name: oauth2
            parameters:
              name: amazing-service
              client_id: AMAZING-CLIENT-ID
              client_secret: AMAZING-CLIENT-SECRET
              redirect_uri: http://amazing-domain/endpoint/
          - name: basic-auth
            parameters:
              username: smith
              password: bobSecret
          - name: hmac-auth
            parameters:
              username: james
          - name: jwt
            parameters:
              key:       "9efdde658a1b4b6e869d57d35dc8d7fb"
              secret:    "1bf8825a9f0e44a0bfb18f7dacf5c43f"
              algorithm: "HS256"
    #****************#
    #    PLUGINS     #
    #****************#
    - role: ansible-kong            ## ADD rate-limiting plugin obj (global)
      kong_task: plugin
      kong_plugin_config:
        name: rate-limiting
        config: { minute: 50, hour: 500 }
      kong_delete_plugin_obj: false
    - role: ansible-kong            ## DELETE rate-limiting plugin obj for svcOne service and consumerOne consumer
      kong_task: plugin
      kong_plugin_config:
        name: rate-limiting
        service: svcOne
        consumer: consumerOne
        config: { minute: 20, hour: 500 }
      kong_delete_plugin_obj: true
    - role: ansible-kong            ## ADD plugin obj for svcOne service
      kong_task: plugin
      kong_plugin_config:
        name: oauth2
        service: svcOne
        config:
          enable_authorization_code: true
          scopes: "email,phone,address"
          mandatory_scope: true
    - role: ansible-kong            ## ADD plugin obj for svcOne service
      kong_task: plugin
      kong_plugin_config:
        name: cors
        service: svcOne
        config:
          origins: "*"
          methods: "GET, POST, PATCH, PUT, DELETE"
          headers: "Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Auth-Token, Access-Control-Allow-Origin, Authorization"
          exposed_headers: "X-Auth-Token"
          credentials: true
          max_age: 3600
    - role: ansible-kong            ## ADD plugin obj for svcOne service
      kong_task: plugin
      kong_plugin_config:
        name: basic-auth
        service: svcOne
        config: { hide_credentials: true }
    - role: ansible-kong            ## ADD plugin obj for svcOne service
      kong_task: plugin
      kong_plugin_config:
        name: key-auth
        service: svcOne
        config: { key_names: X-Api-Access-Key }
    - role: ansible-kong            ## ADD plugin obj for svcOne service
      kong_task: plugin
      kong_plugin_config:
        name: acl
        service: svcOne
        config: { whitelist: "svcOne-user-group, another-user-group" }
```

## Routes, Path Matching and ACLs

Kong uses different [algorithms](https://docs.konghq.com/2.0.x/admin-api/#path-handling-algorithms) to calculate how to go from a Request -> Route -> Service -> Proxy Request.
Currently we use `v0` with `strip_path=true` for all Routes.

|service.path|route.path|route.strip_path|route.path_handling|request path|proxied path|
|------------|----------|----------------|-------------------|------------|------------|
|/s 	       |/tv0/     | true 	         | v0 	             | /tv0/req   | /s/req     |

Most matching we do is via the [Request Path](https://docs.konghq.com/0.13.x/proxy/#request-path),
we typlically don't match based on `host` or `method`, therefore "**a client request's path must be prefixed with one of the values of the paths attribute.**"

### Reporting Service Routing Example

|#|request path                           |route.path                                               |service.path                 |proxied path                                 |
|-|---------------------------------------|---------------------------------------------------------|-----------------------------|---------------------------------------------|
|1|/reporting-service/realtime            |[/reporting-service, /reporting-service/realtime]        |/reporting-service/reporting |/reporting-service/reporting                 |
|2|/reporting-service/personalcontent     |[/reporting-service, /reporting-service/realtime]        |/reporting-service/reporting |/reporting-service/reporting/personalcontent |
|3|/reporting-service/realtime            |[/reporting-service, /realtime]                          |/reporting-service/reporting |/reporting-service/reporting/realtime        |
|4|/reporting-service/restricted/realtime |[/reporting-service <sup>[1]</sup>, /reporting-service/restricted <sup>[2]</sup>]      |/reporting-service/reporting |/reporting-service/reporting/realtime        |

> Request #1:
* `/reporting-service/realtime` matches 2nd Route path
* Intermediary path is `[/reporting-service/reporting][/reporting-service/realtime]` (Service path + Request path)
* `strip_path=true` so `/reporting-service/realtime` is removed (because this is the **Route** path which was **matched**) leaving `/reporting-service/reporting` as the proxied path

> Request #2:
* `/reporting-service/personalcontent` matches 1st Route path due to [path matching](https://docs.konghq.com/0.13.x/proxy/#request-path) rules
* Intermediary path is `[/reporting-service/reporting][/reporting-service/personalcontent]`
* `strip_path=true` so `/reporting-service` is removed leaving `/reporting-service/reporting/personalcontent` as the proxied path

> Request #3:
* `/reporting-service/realtime` matches 1st Route path - the request path must be **prefixed** with one of the values of the paths attribute
* Intermediary path is `[/reporting-service/reporting][/reporting-service/realtime]`
* `strip_path=true` so `/reporting-service` is removed leaving `/reporting-service/reporting/realtime` as the proxied path

> Request #4:
* `/reporting-service/restricted/realtime` matches 2nd Route path
* Intermediary path is `[/reporting-service/reporting][/reporting-service/restricted/realtime]`
* `strip_path=true` so `/reporting-service/restricted` is removed leaving `/reporting-service/reporting/realtime` as the proxied path
* Different ACLs can be applied depending on Route matched <sup>[1]</sup> and <sup>[2]</sup>. See ACLs section below.

### ACLs

An ACL plugin can be applied to a Route, Service or Globally. The plugin [precedence rules](https://docs.konghq.com/0.13.x/admin-api/#precedence) decide which plugin configuration to choose.
Requests #3 and #4 above are matched by the 1st and 2nd Route paths respectively. Depending on which Route path is matched determines which ACLs are applied.

For example, in Request #3 `/reporting-service` was the matched Route path, therefore any ACL plugins which have been applied to **this Route object** will be applied.

With Request #4 `/reporting-service/restricted` was the matched path, therefore any ACL plugins associated with this Route object will be applied. Restricted ACL <sup>[2]</sup> is applied here.

### Shortcutting Paths
All of the Routes configured for Services follow the pattern of having a catch-all Route path, e.g. `/reporting-service`. This allows any API requests to be mapped to an Upstream without any addition configuration.

For example, creating Upstream endpoints `personalcontent` or `events/registration` will allow requests `/reporting-service/personalcontent` and `/reporting-service/events/registration` without any addition Kong configuration.

However, if a separate Route is applying a different ACL to a particular path, then it needs to be excluded from the catch-all Route.

#### Example

* Route A -> paths `[/reporting-service]`            (`ACL 1` restrictions applied)
* Route B -> paths `[/reporting-service/restricted]` (`ACL 2` restrictions applied)

| | | | | | | |
|-|-|-|-|-|-|-|
|`ACL 1` credentials |-> |request `/reporting-service/realtime` |-> |matches Route A |-> |Upstream `/reporting-service/reporting/realtime`|
|`ACL 2` credentials |-> |request `/reporting-service/restricted/realtime` |-> |matches Route B |-> |Upstream `/reporting-service/reporting/realtime`|

Because of Kong's `strip_path` functionality, both requests map correctly to the Upstream service. However, we don't want `ACL 1` credentials access to be able to request `/reporting-service/realtime`, it should only be possible to request it via `/reporting-service/restricted/realtime` using `ACL 2` credentials.

The workaround for this, counterintuitively, is to add the path you **want** to restrict to the Route you **don't want** it to access

* Route A -> paths `[/reporting-service, /reporting-service/realtime]` (`ACL 1` restrictions applied)

This shortcuts Kong's path matching and `strip_path` functionality to produce the following invalid route:

| | | | | | | |
|-|-|-|-|-|-|-|
|`ACL 1` credentials |-> |request `/reporting-service/realtime` |-> |matches Route A |-> |Upstream `/reporting-service/reporting`|


## Testing ##

To run integration tests of this role

```
kitchen test --destroy=never && docker kill node0 node1 postgres && docker rm node0 node1 postgres
```

> **Note:**
> `--destroy=never` must be supplied because two nodes are required to be running for all the tests to pass. The `docker` commands remove the left over containers for the next platform run.

> **Note:**
> Docker-in-Docker doesn't work on Linux (AUFS 'already stacked' error). The Postgres container runs locally (i.e. Kitchen host) rather than from inside the container started by Kitchen.

## Dependencies
none
