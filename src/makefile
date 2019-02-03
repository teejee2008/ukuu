SHELL=/bin/bash
CFLAGS=--std=c99

prefix=/usr
bindir=$(prefix)/bin
sharedir=$(prefix)/share
localedir=$(sharedir)/locale
launcherdir=$(sharedir)/applications
polkitdir=$(sharedir)/polkit-1/actions
mandir=$(sharedir)/man
man1dir=$(mandir)/man1

app_name=ukuu

# vte -----------------------------

vte_symbol = -D VTE_291
vte_version=$(shell { (pkg-config --modversion vte-2.91 | cut -d. -f 2); } )
vala_version=$(shell { (valac --version | cut -d. -f 2); } )
dist_id=$(shell { (lsb_release -i -s); } )
dist_codename=$(shell { (lsb_release -c -s); } )

vte_version=$(shell { ((ldconfig -p | grep libvte-2.91*.so) >/dev/null && echo 'vte-2.91') || echo 'vte-2.90'; } )

# symbols --------------------------

define_symbols=$(shell { echo "${vte_symbol}"; } )

all: app app-gtk app-translations

app-gtk:
	# app-gtk
	valac -X -D'GETTEXT_PACKAGE="${app_name}"' --Xcc="-lm" ${define_symbols} \
		Common/*.vala Gtk/*.vala Utility/*.vala Utility/Gtk/*.vala \
		-o ${app_name}-gtk \
		--pkg glib-2.0 --pkg gio-unix-2.0 --pkg posix --pkg gtk+-3.0 --pkg gee-0.8 --pkg json-glib-1.0 --pkg $(vte_version)

app:
	# app
	valac -X -D'GETTEXT_PACKAGE="${app_name}"' --Xcc="-lm" \
		Common/*.vala Console/*.vala Utility/*.vala \
		-o ${app_name} \
		--pkg glib-2.0 --pkg gio-unix-2.0 --pkg posix --pkg gee-0.8 --pkg libsoup-2.4 --pkg json-glib-1.0

app-translations:

	# update translation template
	find . -iname "*.vala" | xargs xgettext --from-code=UTF-8 --language=C --keyword=_ \
		--copyright-holder='Tony George (teejeetech@gmail.com)' \
		--package-name="${app_name}" \
		--package-version='1.6' \
		--msgid-bugs-address='teejeetech@gmail.com' \
		--escape --sort-output -o ../${app_name}.pot
	
	# update translation files
	# am ar az bg ca cs da de el en_GB es et eu fr he hi hr hu ia id is it ko lt nb ne nl pl pt pt_BR ro ru sk sr sv tr uk vi zh_CN
	for lang in es fr hr nl pl ru sv tr; do \
		msgmerge --update -v ../po/${app_name}-$$lang.po ../${app_name}.pot ; \
	done
	
clean:
	rm -rfv ../release/{source,i386,amd64,armel,armhf}
	rm -rfv ../release/*.{run,deb}
	rm -rfv *.c *.o *.mo
	rm -fv ${app_name} ${app_name}-gtk

install:
	mkdir -p "$(DESTDIR)$(bindir)"
	mkdir -p "$(DESTDIR)$(sharedir)"
	mkdir -p "$(DESTDIR)$(mandir)"
	mkdir -p "$(DESTDIR)$(man1dir)"
	mkdir -p "$(DESTDIR)$(launcherdir)"
	mkdir -p "$(DESTDIR)$(polkitdir)"
	mkdir -p "$(DESTDIR)$(sharedir)/glib-2.0/schemas/"
	mkdir -p "$(DESTDIR)$(sharedir)/${app_name}"
	mkdir -p "$(DESTDIR)$(sharedir)/pixmaps"

	# binary
	install -m 0755 ${app_name} "$(DESTDIR)$(bindir)"
	install -m 0755 ${app_name}-gtk "$(DESTDIR)$(bindir)"
	install -m 0755 ${app_name}-uninstall "$(DESTDIR)$(bindir)"

	# shared files
	cp -dpr --no-preserve=ownership -t "$(DESTDIR)$(sharedir)/${app_name}" ./share/${app_name}/*
	chmod --recursive 0755 $(DESTDIR)$(sharedir)/${app_name}/*

	# polkit policy file
	#install -m 0644 ./share/polkit-1/actions/in.teejeetech.pkexec.ukuu.policy "$(DESTDIR)$(polkitdir)"

	# launcher
	install -m 0755 ${app_name}.desktop "$(DESTDIR)$(launcherdir)"
	
	# app icon
	install -m 0755 ./share/pixmaps/${app_name}.* "$(DESTDIR)$(sharedir)/pixmaps"

	# translations
	for lang in es fr hr nl pl ru sv tr; do \
		mkdir -p "$(DESTDIR)$(localedir)/$$lang/LC_MESSAGES"; \
		msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/$$lang/LC_MESSAGES/${app_name}.mo" ../po/${app_name}-$$lang.po ; \
	done

uninstall:

	# binary
	rm -f "$(DESTDIR)$(bindir)/${app_name}"
	rm -f "$(DESTDIR)$(bindir)/${app_name}-uninstall"

	# shared files
	rm -rf "$(DESTDIR)$(sharedir)/${app_name}"

	# polkit policy file
	#rm -f "$(DESTDIR)$(polkitdir)/in.teejeetech.pkexec.ukuu.policy"

	# launcher
	rm -f "$(DESTDIR)$(launcherdir)/${app_name}.desktop"
	
	# app icon
	rm -f "$(DESTDIR)$(sharedir)/pixmaps/${app_name}.png"

    # translations
	rm -f $(DESTDIR)$(localedir)/*/LC_MESSAGES/${app_name}.mo

	# startup scripts
	rm -f $(DESTDIR)/home/*/.config/ukuu-notify.sh
	rm -f $(DESTDIR)/home/*/.config/autostart/ukuu.desktop
