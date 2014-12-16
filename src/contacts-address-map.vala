/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
/*
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

using Champlain;
using Folks;
using Geocode;
using Gee;
using Gtk;
using GtkChamplain;

[GtkTemplate (ui = "/org/gnome/contacts/ui/contacts-address-map.ui")]
public class Contacts.AddressMap : Frame {

  [GtkChild]
  private Stack map_stack;

  [GtkChild]
  private Grid map_grid;

  [GtkChild]
  private Gtk.Image map_icon;

  private Set<PostalAddressFieldDetails> addresses;
  private GLib.List<Place> found_places;
  private Champlain.View map_view;
  private MarkerLayer marker_layer;
  private Mutex mutex;
  private ulong alloc_id = 0;

  public AddressMap (Contact c, Set<PostalAddressFieldDetails> postal_addresses) {
    var map = new Embed ();
    var map_factory = MapSourceFactory.dup_default ();
    map_grid.add (map);

    map_view = map.get_view ();
    map_view.set_map_source (map_factory.create (MAP_SOURCE_OSM_MAPQUEST));
    map_view.zoom_level = map_view.max_zoom_level - 2;

    marker_layer = new MarkerLayer ();
    map_view.add_layer (marker_layer);

    /* This is a hack to make sure we do not get the FLEUR
     * drag cursor on click. Ideally champlain would let us
     * turn this of with a property. */
    map.get_child ().button_press_event.connect (() => {
	map.get_child ().get_window ().set_cursor (null);
	return false;
      });

    /* Do not propagate event to the Champlain clutter stage */
    map_view.get_stage ().captured_event.connect (() => { return true; });

    map.button_press_event.connect(() => {
	activate_action ("org.gnome.Maps",
			 "show-contact",
			 new Variant ("s", c.individual.id),
			 Gtk.get_current_event_time ());
	return true;
      });

    addresses = postal_addresses;
    found_places = new GLib.List<Place>();
    mutex = Mutex ();
  }

  public void load () {
    map_stack.visible_child = map_icon;
    var geocodes = 0;

    foreach (var addr in addresses) {
      Contact.geocode_address.begin (addr.value, (object, res) => {
	  mutex.lock ();

	  var place = Contact.geocode_address.end (res);
	  geocodes++;

	  if (place != null)
	    found_places.prepend (place);

	  if (geocodes == addresses.size && found_places.length () > 0)
	    show_map ();

	  mutex.unlock ();
	});
    }
  }

  private void show_pin () {
    var theme = IconTheme.get_default ();
    var actor = new Clutter.Actor ();

    try {
      var pixbuf = theme.load_icon ("maps-pin", 0, 0);
      var image = new Clutter.Image ();

      image.set_data (pixbuf.get_pixels (),
		      Cogl.PixelFormat.RGBA_8888,
		      pixbuf.get_width (),
		      pixbuf.get_height (),
		      pixbuf.get_rowstride ());


      actor.set_content (image);
      actor.set_size (pixbuf.get_width (),
		      pixbuf.get_height ());
    } catch (GLib.Error e) {
      /* No good things to do here */
    }

    var marker = new Marker ();
    var place = found_places.nth_data (0);

    marker.latitude = place.location.latitude;
    marker.longitude = place.location.longitude;

    marker.add_child (actor);
    marker_layer.add_marker (marker);
  }

  private void show_labels () {
    foreach (var place in found_places) {
      var label = new Champlain.Label ();

      /* Getting street address resolution (house number)
       * from OpenStreetMap is quite rare unfortunately */
      if (place.street_address != null)
	label.text = place.street_address;
      else
	label.text = place.street;

      label.latitude = place.location.latitude;
      label.longitude = place.location.longitude;
      marker_layer.add_marker(label);
    }
  }

  void on_allocation_changed () {
    if (alloc_id == 0)
      return;

    var markers = (marker_layer as Clutter.Actor).get_children ();
    if ((markers.nth_data (0) as Marker).height == 0)
      return;

    marker_layer.disconnect (alloc_id);
    alloc_id = 0;

    if (found_places.length () == 1) {
      var place = found_places.nth_data (0);

      map_view.center_on (place.location.latitude,
			  place.location.longitude);
    } else {
      var bbox = new Champlain.BoundingBox ();

      /* Make sure that the markers are visible */
      foreach (var marker in markers) {
	var x = map_view.longitude_to_x ((marker as Marker).longitude);
	var y = map_view.latitude_to_y ((marker as Marker).latitude);

	/* 256 is the only supported tile size in Champlain */
	var lat = map_view.y_to_latitude (y - marker.height * 256);
	var lon = map_view.x_to_longitude (x + marker.width * 256);

	bbox.extend (lat, lon);
	bbox.extend ((marker as Marker).latitude,
		     (marker as Marker).longitude);
      }
      map_view.ensure_visible (bbox, false);
    }
  }

  private void show_map () {
    if (found_places.length () == 0) {
      map_stack.visible_child = map_icon;
      return;
    }

    if (found_places.length () == 1) {
      show_pin ();
    } else {
      show_labels ();
    }

    map_stack.visible_child = map_grid;

    /* We need to make sure that the markers knows about their width
     * before we calculate the visible bounding box and show
     * the markers.*/
    alloc_id = marker_layer.allocation_changed.connect (on_allocation_changed);
  }
}
