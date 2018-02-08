Lager Logstash Backend
======================

Backend for lager data into log stash. This a modification of [mhald repo],
this fork was done because we need to correctly handle other scenarios
not contemplated in the original lib to being able to integrate lager with the
[EKL Stack]. This repo adds UTC handling for logs in the format [ISO8601]
required by [Logstash], because the old one sent one with ` UTC` added
at the end making it invalid. Also was added a way to set  an `ENV`
environment variable directly to the log's data sent as the field `env`.

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

output {
    elasticsearch { hosts => ["elasticsearch:9200"] }
    stdout { codec => rubydebug }
}
```

# Configure erlang
## UTC
Logstash to work correctly **needs UTC timestamps**, for that reason or
your host is UTC or you configure `sasl` in UTC.
~~~
{sasl, [{utc_log, true}]}
~~~

## Environment
Please set the `ENV` variable, if not defined the default value
of the `env` field wil be `debug` otherwise is the variable's value.


# Testing

On the erlang shell use

```
$ rebar3 shell
1> lager:log(error, self(), "Error notice").
```

[mhald repo]: https://github.com/mhald/lager_logstash_backend
[EKL Stack]: https://www.elastic.co/elk-stack
[Logstash]: https://www.elastic.co/products/logstash
[ISO8601]: https://en.wikipedia.org/wiki/ISO_8601
