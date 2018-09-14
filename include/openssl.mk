REPO = https://github.com/openssl/openssl.git
MODULE = openssl
CURRENT = $(realpath ./)/$(MODULE)
CD = cd $(CURRENT) &&
GIT = git --git-dir=$(CURRENT)/.git

default: install

initial: install

# We are not going to install
install: make
	if [ ! -f $(INST_PATH)/lib/libssl.a ]; then \
		$(CD) make install; \
	fi

make: configure
	$(CD) make

configure: clone
	if [ ! -f $(CURRENT)/Makefile ]; then \
		$(CD) ./config --prefix=$(INST_PATH); \
	fi

clone:
	if [ ! -d $(CURRENT)/.git ]; then \
		$(GIT) clone $(REPO); \
		$(GIT) checkout master; \
	fi
