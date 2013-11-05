lager_logstash_backend
======================

Backend for lager data into log stash

# Logstash

Install logstash and setup the sample.config with information about your logstash server.

Sample logstash config:

```
input {
  stdin {
    type => "stdin-type"
  }

  file {
    type => "syslog"

    # Wildcards work, here :)
    path => [ "/var/log/*.log", "/var/log/messages", "/var/log/syslog" ]
  }

  udp {
    format => "json"
    port => 9125
    type => "erlang"
  }
}

output {
  stdout { }
  elasticsearch { embedded => true }
}
```

# Testing


Build using

```
./rebar get-deps
make
make shell
```

On the erlang shell use

```
lager:log(error, self(), "Error notice").
```
