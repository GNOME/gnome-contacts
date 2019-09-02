# GNOME Contacts

Contacts organizes your contacts information from all your online and offline
sources, providing a centralized place for managing your contacts.

[![Flatpak](https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Flathub-badge-en.svg/240px-Flathub-badge-en.svg.png)](https://flathub.org/apps/details/org.gnome.Contacts)

## Building

You can build and install Contacts using [Meson](http://mesonbuild.com/):

```sh
meson build
ninja -C build
ninja -C build install
```

## Contributing

The code and issue tracker of Contacts can be found at the
[gnome-contacts repository](https://gitlab.gnome.org/GNOME/gnome-contacts) on
GNOME's GitLab instance.

### Reporting issues

If you find a bug in Contacts, please [file an
issue](https://gitlab.gnome.org/GNOME/gnome-contacts/issues) with reproducible
steps and the version of Contacts you were using at that point.

### Developers

If you want to contribute functionality or bug fixes to Contacts, you should
fork the Contacts repository, commit your changes, and then [open a merge
request](https://gitlab.gnome.org/GNOME/gnome-contacts/merge_requests/new) (MR).
If the MR fixes an existing issue, please refer to that issue in the
description of the commit.

### Translators

If GNOME Contacts is not translated in your language or you believe that the
current translation has errors, then you can join one of the various
translation teams in GNOME. Translators do not commit directly to Git, but are
advised to use our separate translation infrastructure instead. [More info can
be found at GNOME's Wiki page on the translation
project](https://wiki.gnome.org/TranslationProject/JoiningTranslation).

## More information

Contacts has its own web page on <https://wiki.gnome.org/Apps/Contacts>.

To discuss issues with developers and other users, you can subscribe to the
[mailing list](https://mail.gnome.org/mailman/listinfo/gnome-contacts-list)
or join [#contacts](irc://irc.gnome.org/contacts) on irc.gnome.org.

If you would like to get involved with GNOME projects, please also visit our
[Newcomers page](https://wiki.gnome.org/TranslationProject/JoiningTranslation)
on the Wiki.
