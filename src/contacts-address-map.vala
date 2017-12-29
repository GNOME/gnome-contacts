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
 *
 * Author: Jonas Danielsson <jonas@threetimestwo.org>
 */

using Champlain;
using Folks;
using Gdk;
using Gee;
using Geocode;
using Gtk;
using GtkClutter;

[GtkTemplate (ui = "/org/gnome/Contacts/ui/contacts-address-map.ui")]
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
    var maps_id = "org.gnome.Maps";
    var maps_info = new DesktopAppInfo (maps_id + ".desktop");
    var map_factory = MapSourceFactory.dup_default ();
    map_grid.add (map);

    map_view = new Champlain.View ();
    map_view.set_map_source (map_factory.create (MAP_SOURCE_OSM_MAPQUEST));
    map_view.zoom_level = map_view.max_zoom_level - 2;
    map.get_stage ().add_child (map_view);

    marker_layer = new MarkerLayer ();
    map_view.add_layer (marker_layer);

    /* Disable all events for the map */
    map.get_stage ().captured_event.connect (() => { return true; });

    if (maps_info != null) {
      /* Set cursor as HAND1 to indicate the map is clickable */
      map.realize.connect (() => {
          var hand_cursor = new Cursor.for_display (Display.get_default (), CursorType.HAND1);
          map.get_window ().set_cursor (hand_cursor);
        });

      map.button_press_event.connect(() => {
          activate_action (maps_id,
                           "show-contact",
                           new Variant ("s", c.individual.id),
                           Gtk.get_current_event_time ());
          return true;
      });

    } else {
      map.set_tooltip_text (_("Install GNOME Maps to open location."));
    }

    addresses = postal_addresses;
    found_places = new GLib.List<Place> ();
    mutex = Mutex ();
  }

  public void load () {
    map_stack.visible_child = map_icon;
    var geocodes = 0;

    foreach (var addr in addresses) {
      geocode_address.begin (addr.value, (object, res) => {
          mutex.lock ();

          var place = geocode_address.end (res);
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
      var pixbuf = theme.load_icon ("mark-location", 32, 0);
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

    Idle.add ( () => {
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

        return false;
      });
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

  private async Place geocode_address (PostalAddress addr) {
    SourceFunc callback = geocode_address.callback;

    var params = new HashTable<string, GLib.Value?>(str_hash, str_equal);
    if (is_set (addr.street))
      params["street"] = addr.street;
    if (is_set (addr.locality))
      params["locality"] = addr.locality;
    if (is_set (addr.region))
      params["region"] = addr.region;
    if (is_set (addr.country))
      params["country"] = addr.country;

    Place? place = null;
    var forward = new Forward.for_params (params);
    forward.search_async.begin (null, (object, res) => {
        try {
          var places = forward.search_async.end (res);

          place = places.nth_data (0);
          callback ();
        } catch (GLib.Error e) {
          debug ("No geocode result found for contact");
          callback ();
        }
      });
    yield;
    return place;
  }
}
