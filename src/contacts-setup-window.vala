/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;
using Folks;

public class Contacts.SetupWindow : Gtk.Window {
  public bool succeeded;
  private ulong source_list_changed_id;
  public Label title_label;
  public Grid content_grid;
  ToolButton select_button;
  ListStore list_store;
  TreeView tree_view;

  public void update_content () {
    foreach (var w in content_grid.get_children ()) {
      w.destroy ();
    }

    var l = new Label (_("Welcome to Contacts! Please select where you want to keep your address book:"));
    l.set_line_wrap (true);
    l.set_max_width_chars (5);
    l.set_halign (Align.FILL);
    l.set_alignment (0.0f, 0.5f);
    content_grid.add (l);

    Button goa_button;

    if (has_goa_account ()) {
      select_button.show ();

      tree_view = new TreeView ();
      var store = new ListStore (2, typeof (string), typeof (Folks.PersonaStore));
      list_store = store;
      tree_view.set_model (store);
      tree_view.set_headers_visible (false);
      tree_view.get_selection ().set_mode (SelectionMode.BROWSE);

      var column = new Gtk.TreeViewColumn ();
      tree_view.append_column (column);

      var renderer = new Gtk.CellRendererText ();
      column.pack_start (renderer, false);
      column.add_attribute (renderer, "text", 0);

      var scrolled = new ScrolledWindow(null, null);
      scrolled.set_size_request (340, 220);
      scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
      scrolled.set_vexpand (false);
      scrolled.set_shadow_type (ShadowType.IN);
      scrolled.add (tree_view);

      content_grid.add (scrolled);

      TreeIter iter;
      foreach (var persona_store in Contact.get_eds_address_books ()) {
	var name = Contact.format_persona_store_name (persona_store);
	store.append (out iter);
	store.set (iter, 0, name, 1, persona_store);
	if (persona_store == App.app.contacts_store.aggregator.primary_store) {
	  tree_view.get_selection ().select_iter (iter);
	}
      }

      goa_button = new Button.with_label (_("Online Account Settings"));
      content_grid.add (goa_button);

    } else {
      select_button.hide ();
      l = new Label (_("Setup an online account or use a local address book"));
      content_grid.add (l);

      goa_button = new Button.with_label (_("Online Accounts"));
      content_grid.add (goa_button);

      var b = new Button.with_label (_("Use Local Address Book"));
      content_grid.add (b);

      b.clicked.connect ( () => {
	  var source = eds_source_list.peek_source_by_uid (eds_local_store);
	  select_source (source);
	});
    }

    goa_button.clicked.connect ( (button) => {
	try {
	  update_content ();
	  Process.spawn_command_line_async ("gnome-control-center online-accounts");
	}
	catch (Error e) {
	  // TODO: Show error dialog
	}
      });

    content_grid.show_all ();
  }

  private void select_source (E.Source source) {
    try {
      E.BookClient.set_default_source (source);
    } catch {
      warning ("Failed to set address book");
    }
    succeeded = true;
    App.app.settings.set_boolean ("did-initial-setup", true);
    destroy ();
  }


  public SetupWindow () {
    var grid = new Grid ();
    this.add (grid);
    this.set_title (_("Contacts Setup"));
    this.set_default_size (640, 480);

    this.hide_titlebar_when_maximized = true;

    var toolbar = new Toolbar ();
    toolbar.set_icon_size (IconSize.MENU);
    toolbar.get_style_context ().add_class (STYLE_CLASS_MENUBAR);
    toolbar.set_vexpand (false);
    toolbar.set_hexpand (true);
    grid.attach (toolbar, 0, 0, 1, 1);

    var cancel_button = new ToolButton (null, _("Cancel"));
    cancel_button.is_important = true;
    toolbar.add (cancel_button);
    cancel_button.clicked.connect ( (button) => {
	this.destroy ();
      });

    var item = new ToolItem ();
    title_label = new Label ("");
    title_label.set_markup ("<b>%s</b>".printf (_("Contacts Setup")));
    title_label.set_no_show_all (true);
    item.add (title_label);
    item.set_expand (true);
    toolbar.add (item);

    select_button = new ToolButton (null, _("Select"));
    select_button.is_important = true;
    select_button.set_no_show_all (true);
    toolbar.add (select_button);
    select_button.clicked.connect ( (button) => {
	PersonaStore selected_store;
	TreeIter iter;

	if (tree_view.get_selection() .get_selected (null, out iter)) {
	  list_store.get (iter, 1, out selected_store);

	  var e_store = selected_store as Edsf.PersonaStore;
	  select_source (e_store.source);
	}
      });

    var frame = new Frame (null);
    frame.get_style_context ().add_class ("contacts-content");

    var box = new EventBox ();
    box.set_hexpand (true);
    box.set_vexpand (true);
    box.get_style_context ().add_class ("contacts-main-view");
    box.get_style_context ().add_class ("view");

    frame.add (box);
    grid.attach (frame, 0, 1, 1, 1);

    content_grid = new Grid ();
    content_grid.set_border_width (12);
    content_grid.set_orientation (Orientation.VERTICAL);
    content_grid.set_halign (Align.CENTER);
    content_grid.set_row_spacing (8);
    box.add (content_grid);

    update_content ();

    source_list_changed_id = eds_source_list.changed.connect ( () => {
	update_content ();
      });

    grid.show_all ();
  }

  public override void destroy () {
    if (source_list_changed_id != 0) {
      eds_source_list.disconnect (source_list_changed_id);
      source_list_changed_id = 0;
    }
    base.destroy ();
  }

  public override bool window_state_event (Gdk.EventWindowState e) {
    base.window_state_event (e);

    if ((e.new_window_state & Gdk.WindowState.MAXIMIZED) != 0)
      title_label.show ();
    else
      title_label.hide ();

    return false;
  }
}
