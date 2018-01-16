# Gradual Function Type Checking for Lua 5.1, 5.2 & 5.3.
# Copyright (C) 2014-2018 Gary V. Vaughan

LDOC	= ldoc
LUA	= lua
MKDIR	= mkdir -p
SED	= sed
SPECL	= specl

VERSION	= git

luadir	= lib/typecheck
SOURCES =				\
	$(luadir)/init.lua		\
	$(luadir)/version.lua		\
	$(NOTHING_ELSE)


all: $(luadir)/version.lua doc


$(luadir)/version.lua: Makefile
	echo "return 'Gradual Function Typechecks / $(VERSION)'" > '$@'

doc: build-aux/config.ld $(SOURCES)
	$(LDOC) -c build-aux/config.ld .

build-aux/config.ld: build-aux/config.ld.in Makefile
	$(SED) -e 's,@PACKAGE_VERSION@,$(VERSION),' '$<' > '$@'


CHECK_ENV = LUA=$(LUA)

check: $(SOURCES)
	LUA=$(LUA) $(SPECL) $(SPECL_OPTS) spec/*_spec.yaml
