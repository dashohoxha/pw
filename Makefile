PREFIX ?= /usr
DESTDIR ?=
BINDIR ?= $(DESTDIR)$(PREFIX)/bin
LIBDIR ?= $(DESTDIR)$(PREFIX)/lib
MANDIR ?= $(DESTDIR)$(PREFIX)/share/man

PLATFORM := $(shell uname | cut -d _ -f 1 | tr '[:upper:]' '[:lower:]')

all:
	@echo "Password manager is a shell script, so there is nothing to do. Try \"make install\" instead."

install:
	@install -v -d "$(BINDIR)/"
	@sed -e "s/^PLATFORM=.*/PLATFORM=$(PLATFORM)/" \
	    -e "s:^LIBDIR=.*:LIBDIR=$(LIBDIR)/pw:" \
	    src/pw.sh > "$(BINDIR)/pw"
	@chmod 0755 "$(BINDIR)/pw"

	@install -v -d "$(LIBDIR)/pw/platform/"
	@install -m 0644 -v "src/platform/$(PLATFORM).sh" "$(LIBDIR)/pw/platform/" 2>/dev/null || true

	@install -v -d "$(MANDIR)/pw/"
	@install -m 0644 -v man/pw.1 "$(MANDIR)/pw/pw.1"

uninstall:
	@rm -vrf \
		"$(BINDIR)/pw" \
		"$(LIBDIR)/pw" \
		"$(MANDIR)/man1/pw.1" \
	@rmdir "$(LIBDIR)/pw" 2>/dev/null || true

TESTS = $(sort $(wildcard tests/t*.t))

test: $(TESTS)

$(TESTS):
	@$@ $(PW_TEST_OPTS)

clean:
	$(RM) -rf tests/test-results/ tests/trash\ directory.*/ tests/gnupg/random_seed

.PHONY: install uninstall test clean $(TESTS)
