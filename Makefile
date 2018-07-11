PREFIX ?= /usr
DESTDIR ?=
BINDIR ?= $(DESTDIR)$(PREFIX)/bin
LIBDIR ?= $(DESTDIR)$(PREFIX)/lib/pw
MANDIR ?= $(DESTDIR)$(PREFIX)/share/man/man1

all: install

install:
	@install -v -d "$(BINDIR)/"
	@install -v -m 0755 src/pw.sh "$(BINDIR)/pw"
	@sed -i $(BINDIR)/pw -e "s#^LIBDIR=.*#LIBDIR=\"$(PREFIX)/lib/pw\"#"

	@install -v -d "$(LIBDIR)/"
	@cp -v -r src/platform src/ext "$(LIBDIR)"

	@install -v -d "$(MANDIR)/"
	@install -v -m 0644 man/pw.1 "$(MANDIR)/pw.1"

uninstall:
	@rm -vrf "$(BINDIR)/pw" "$(LIBDIR)" "$(MANDIR)/pw.1"

deb:
	./deb.sh

TESTS = $(sort $(wildcard tests/t*.t))

test: $(TESTS)

$(TESTS):
	@$@ $(PW_TEST_OPTS)

clean:
	$(RM) -rf tests/test-results/ tests/trash\ directory.*/ tests/gnupg/random_seed
	$(RM) -f pw.deb

.PHONY: install uninstall deb test clean $(TESTS)
