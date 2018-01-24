# GNOME Contacts
Contacts organizes your contacts information from all your online and offline
sources, providing a centralized place for managing your contacts.

## Building
You can build and install Contacts using [Meson](http://mesonbuild.com/):
```sh
meson build
ninja -C build
ninja -C build install
```

## Issue tracker
The code and issue tracker of Contacts can be found at the
[gnome-contacts repository](https://gitlab.gnome.org/GNOME/gnome-contacts) on
the GNOME GitLab instance.

If you find a bug in Contacts, please file an issue with reproducible steps and
the version of Contacts (shown in the About dialog, or by running
`gnome-contacts --version`).

If you want to contribute functionality or bug fixes to Contacts, you should
fork the Contacts repository, work on a separate branch, and then open a
merge request (MR) on our GitLab repository. If the MR fixes an existing issue,
please refer to that issue in the description.

## More information
Contacts has its own web page on https://wiki.gnome.org/Apps/Contacts.

To discuss issues with developers and other users, you can subscribe to the
[mailing list](https://mail.gnome.org/mailman/listinfo/gnome-contacts-list)
or join [#contacts](irc://irc.gnome.org/contacts) on irc.gnome.org.
