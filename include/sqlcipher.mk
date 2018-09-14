REPO = https://github.com/sqlcipher/sqlcipher.git
MODULE = sqlcipher
CURRENT = $(realpath ./)/$(MODULE)
CD = cd $(CURRENT) &&
GIT = git --git-dir=$(CURRENT)/.git

default: install

initial: install

# We are not going to install
install: make
	if [ ! -f $(INST_PATH)/lib/libsqlcipher.la ]; then \
		$(CD) make install; \
	fi

make: configure
	$(CD) make all

configure: clone
	if [ ! -f $(CURRENT)/Makefile ]; then \
		$(CD) ./configure --enable-tempstore=yes CFLAGS="-DSQLITE_HAS_CODEC" \
		LDFLAGS="$(INC_PATH)/openssl/libcrypto.a" --prefix=$(INST_PATH); \
	fi

clone:
	if [ ! -d $(CURRENT)/.git ]; then \
		$(GIT) clone $(REPO); \
		$(GIT) checkout master; \
	fi
