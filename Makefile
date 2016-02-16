PREFIX ?= /usr
DESTDIR ?=
BINDIR ?= $(DESTDIR)$(PREFIX)/bin
LIBDIR ?= $(DESTDIR)$(PREFIX)/lib
MANDIR ?= $(DESTDIR)$(PREFIX)/share/man/man1

PW = $(BINDIR)/pw
LIB = $(LIBDIR)/pw

all: install

install:
	@install -v -d "$(BINDIR)/"
	@install -v -m 0755 src/pw.sh "$(PW)"
	@sed -i $(PW) -e "s#^LIBDIR=.*#LIBDIR=\"$(LIB)\"#"

	@install -v -d "$(LIB)/platform/"
	@install -v -m 0644 $(wildcard src/platform/*) "$(LIB)/platform/"

	@install -v -d "$(MANDIR)/"
	@install -v -m 0644 man/pw.1 "$(MANDIR)/pw.1"

uninstall:
	@rm -vrf "$(PW)" "$(LIB)" "$(MANDIR)/pw.1"

TESTS = $(sort $(wildcard tests/t*.t))

test: $(TESTS)

$(TESTS):
	@$@ $(PW_TEST_OPTS)

clean:
	$(RM) -rf tests/test-results/ tests/trash\ directory.*/ tests/gnupg/random_seed

.PHONY: install uninstall test clean $(TESTS)
