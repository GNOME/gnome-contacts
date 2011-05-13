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
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

using Gtk;

public class Contacts.StarredButton : ToggleButton  {
  public StarredButton () {
    var i = new Image.from_icon_name ("non-starred", IconSize.BUTTON);
    set_image (i);
    set_relief (ReliefStyle.NONE);
  }

  public override void toggled () {
    Image image = (Image) get_image ();
    if (get_active ()) {
      image.set_from_icon_name ("starred", IconSize.BUTTON);
    } else {
      image.set_from_icon_name ("non-starred", IconSize.BUTTON);
    }
  }

  /* TODO: This isn't exactly right, as it doesn't paint the focus and stuff.
     But its a good simple start. */
  public override bool draw (Cairo.Context cr) {
    propagate_draw (get_child (), cr);
    return false;
  }
}
