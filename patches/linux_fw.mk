
all:

install:
	mkdir -p $(DESTDIR)$(FIRMWAREDIR)
	cp -r * $(DESTDIR)$(FIRMWAREDIR)
	rm -rf $(DESTDIR)$(FIRMWAREDIR)/usbdux
	find $(DESTDIR)$(FIRMWAREDIR) \( -name 'WHENCE' -or -name 'LICENSE.*' -or \
		-name 'LICENCE.*' \) -exec rm -- {} \;

