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

public class Contacts.NewContactDialog : Dialog {

	public NewContactDialog(Window parent) {
		set_title (_("New contact"));
		set_destroy_with_parent (true);
		set_transient_for (parent);

		add_buttons (Stock.CANCEL, ResponseType.CANCEL,
					 _("Create Contact"), ResponseType.OK);

		set_default_response (ResponseType.OK);

		var box = get_content_area () as Box;
    
		var scrolled = new ScrolledWindow(null, null);
		scrolled.set_size_request (340, 300);
		scrolled.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
		scrolled.set_vexpand (true);
		scrolled.set_hexpand (true);
		scrolled.set_shadow_type (ShadowType.IN);
		scrolled.set_border_width (6);

		box.pack_start (scrolled, true, true, 0);

		var grid = new Grid ();
		scrolled.add_with_viewport (grid);

		var entry = new Entry ();
		grid.add (entry);
	}

	public override void response (int response_id) {
		if (response_id == ResponseType.OK) {
		}
		this.destroy ();
	}
}
