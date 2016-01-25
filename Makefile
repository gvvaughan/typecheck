LDOC	= ldoc
LUA	= lua
MKDIR	= mkdir -p
SED	= sed
SPECL	= specl


all: doc


doc: doc/config.ld typecheck.lua
	$(LDOC) -c doc/config.ld .

doc/config.ld: doc/config.ld.in
	version=`LUA_PATH=$$(pwd)'/?.lua;;' $(LUA) -e 'io.stdout:write(require"typecheck"._VERSION)'`; \
	$(SED) -e "s,@PACKAGE_VERSION@,$$version," '$<' > '$@'


CHECK_ENV = LUA=$(LUA)

check:
	LUA=$(LUA) $(SPECL) $(SPECL_OPTS) specs/*_spec.yaml
