# GNOME Contacts

Contacts organizes your contacts information from all your online and offline
sources, providing a centralized place for managing your contacts.

## Building

You can build, test and install Contacts using [Meson](http://mesonbuild.com/):

```sh
meson setup _build
meson compile -C _build
meson test -C _build
meson install -C _build
```

## Changelog
Starting Contacts 3.25.4, we provide release notes (including unstable releases)
through the AppData file, so app stores (like GNOME Software) can show release
notes to users.

Human-readable textual output (similar to this file) can still be generated
with the following command:

```sh
$ appstreamcli metainfo-to-news _build/data/org.gnome.Contacts.appdata.xml NEWS
```

## Contributing
The code and issue tracker of Contacts can be found at the
[gnome-contacts repository](https://gitlab.gnome.org/GNOME/gnome-contacts) on
GNOME's GitLab instance.

If you're interesting in help out, please take a look at
https://welcome.gnome.org/app/Contacts/ to get started.

Contacts also has its own web page on https://apps.gnome.org/Contacts.

To discuss issues with developers and other users, you can post to the
[GNOME Discourse instance](https://discourse.gnome.org/tags/contacts) with the
`contacts` tag, or join the [#contacts](https://matrix.to/#/#contacts:gnome.org)
Matrix channel.
