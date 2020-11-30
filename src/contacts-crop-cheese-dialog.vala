/*
 * Copyright (C) 2018 Elias Entrup <elias-git@flump.de>
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

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-crop-cheese-dialog.ui")]
public class Contacts.CropCheeseDialog : Gtk.Window {
  [GtkChild]
  private Stack stack;
  [GtkChild]
  private Button take_another_button;

  private Cc.CropArea crop_area;
  private const string STACK_NAME_CROP = "crop";
  private const string STACK_NAME_CHEESE = "cheese";

#if HAVE_CHEESE
  private Cheese.Flash flash;
  private Cheese.Widget cheese;
#endif

  public signal void picture_selected (Gdk.Pixbuf buf);

  public CropCheeseDialog.for_cheese (Gtk.Window parent) {
#if HAVE_CHEESE
    setup_widget (parent);
    this.flash = new Cheese.Flash (this);
    this.cheese = new Cheese.Widget ();
    this.cheese.show ();
    this.stack.add_named (this.cheese, STACK_NAME_CHEESE);
    this.stack.set_visible_child_name (STACK_NAME_CHEESE);
#endif
  }

  public CropCheeseDialog.for_crop (Gtk.Window parent, Gdk.Pixbuf pixbuf) {
    setup_widget (parent);
    this.take_another_button.visible = false;
    this.crop_area.set_picture (pixbuf);
  }

  /* this function is called from both constructors */
  private void setup_widget (Gtk.Window parent) {
    this.set_transient_for (parent);

    this.crop_area = new Cc.CropArea ();
    this.crop_area.set_vexpand (true);
    this.crop_area.set_hexpand (true);
    this.crop_area.set_min_size (48, 48);
    this.crop_area.set_constrain_aspect (true);
    this.stack.add_named (this.crop_area, STACK_NAME_CROP);
  }

  [GtkCallback]
  private void on_cancel_clicked (Button button) {
    this.destroy ();
  }

  [GtkCallback]
  private void on_take_another_clicked (Button button) {
#if HAVE_CHEESE
    this.stack.set_visible_child_name (STACK_NAME_CHEESE);
#endif
  }

  [GtkCallback]
  private void on_take_pic_clicked (Button button) {
#if HAVE_CHEESE
    var camera = this.cheese.get_camera () as Cheese.Camera;
    this.flash.fire ();
    camera.photo_taken.connect ( (pix) => {
        this.stack.set_visible_child_name (STACK_NAME_CROP);
        this.crop_area.set_picture(pix);
    });

    if (!camera.take_photo_pixbuf ()) {
      Utils.show_error_dialog (_("Unable to take photo."),
                               this as Gtk.Window);
    }
#endif
  }

  [GtkCallback]
  private void on_done_clicked (Button button) {
    picture_selected (this.crop_area.get_picture ());
    destroy();
  }
  
  [GtkCallback]
  private void on_destroy () {
#if HAVE_CHEESE
    /* Ensure the Vala garbage collector disposes of the Cheese widget.
     * This prevents the 'Device or resource busy' warnings, see:
     *   https://bugzilla.gnome.org/show_bug.cgi?id=700959
     */
    this.cheese = null;
#endif
  }

}
