#!/usr/bin/make
REBAR=./rebar
CT=./covertool
EUNIT_DIR=./.eunit
SRC_DIR=./src
SERVER := erl -pa ebin -pa deps/*/ebin -smp enable -s lager -config sample.config ${ERL_ARGS}

all: clean deps compile
deps:
				@$(REBAR) get-deps

clean:
				@$(REBAR) clean

compile: deps
				@$(REBAR) compile

test:
				@$(REBAR) compile eunit skip_deps=true
				@$(CT) -cover $(EUNIT_DIR)/eunit.coverdata -output $(EUNIT_DIR)/coverage.xml -src $(SRC_DIR)

shell:			
				${SERVER} -name lager@`hostname` -boot start_sasl
