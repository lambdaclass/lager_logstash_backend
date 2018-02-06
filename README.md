Lager Logstash Backend
======================

Backend for lager data into log stash.

# Logstash

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

# Testing

On the erlang shell use

```
$ rebar3 shell
1> lager:log(error, self(), "Error notice").
```

## Notes
This a modification of [mhald repo](https://github.com/mhald/lager_logstash_backend).
