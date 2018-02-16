Lager Logstash Backend
======================

Backend for lager data into log stash. This a modification of [mhald repo],
this fork was done because we need to correctly handle other scenarios
not contemplated in the original lib to being able to integrate lager with the
[EKL Stack]. This repo adds UTC handling for logs in the format [ISO8601]
required by [Logstash], because the old one was sent  with ` UTC` added
at the end, making it invalid. Also was added a way to set  an `ENV`
environment variable directly to the log's data sent as the field `env`.

A sample project that shows how to use it can be found
[here](https://github.com/lambdaclass/erlang_log_to_kibana_example/).


# Configure erlang with Rebar3
You need to add this project and lager as dependency to your `rebar.config`,
~~~erlang
{deps, [
        lager,
        {lager_logstash_backend,
           {git,"https://github.com/lambdaclass/lager_logstash_backend",
              {tag, "0.1"}}}
]}.
~~~

then also in `rebar.config` set your `sys_config` to configure
the backend.

~~~erlang
{relx,
 [
  {sys_config, "./conf/sys.config"},
  ...
~~~

Then in `sys.config` do specify `sasl` to work in UTC, this
step is required because logstash **needs UTC timestamps**.
~~~
{sasl, [{utc_log, true}]}
~~~

Finally configure the lager backends in `sys.config` too:

~~~erlang
{lager,
  [
   {handlers,
    [
     {lager_logstash_backend,
      [
        {level,             info},
        {logstash_host,     "logstash_host"},
        {logstash_port,     9125},
        {node_role,         "erlang"},
        {node_version,      "0.0.1"},
        {metadata, [
                   {account_token,  [{encoding, string}]},
                   {client_os,      [{encoding, string}]},
                   {client_version, [{encoding, string}]}
                  ]}
      ]}
     ]}
  ]}
~~~

## Environment
The backend will also send the environment variable `ENV` to logstash
as the field `env`, if not defined the default value of the `env` 
field will be `debug` otherwise is the variable's value.

Finally `ERLANG_ELK_LOG_IP` environment variable should hold the IP
that will be sent as field `host`.

# Testing

On the erlang shell use

```
$ rebar3 shell
1> lager:log(error, self(), "Error notice").
```

# Configure Logstash
Install logstash and setup the sample.config with information about your logstash server.

Sample logstash config:

```
input {
    udp  {
        codec => "json"
        port  => 9125
        type  => "erlang"
    }
}

filter {
  mutate {
    add_field => { "env" => "debug" }
    replace => { "host" => "ip_address" }
  }
}

output {
    elasticsearch { hosts => ["elasticsearch:9200"] }
}
```


[mhald repo]: https://github.com/mhald/lager_logstash_backend
[EKL Stack]: https://www.elastic.co/elk-stack
[Logstash]: https://www.elastic.co/products/logstash
[ISO8601]: https://en.wikipedia.org/wiki/ISO_8601
