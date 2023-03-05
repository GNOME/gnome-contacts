/*
 * Copyright (C) 2022 Niels De Graef <nielsdegraef@gmail.com>
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

using Folks;

/**
 * A {@link Chunk} that represents the organizations and/or roles of a contact
 * (similar to {@link Folks.RoleDetails}}. Each element is a
 * {@link Contacts.OrgRole}.
 */
public class Contacts.RolesChunk : BinChunk {

  public override string property_name { get { return "roles"; } }

  construct {
    if (persona != null) {
      assert (persona is RoleDetails);
      unowned var role_details = (RoleDetails) persona;

      foreach (var role_field in role_details.roles) {
        var role = new OrgRole.from_field_details (role_field);
        add_child (role);
      }
    }

    finish_initialization ();
  }

  protected override BinChunkChild create_empty_child () {
    return new OrgRole ();
  }

  public override async void save_to_persona () throws GLib.Error
      requires (this.persona is RoleDetails) {
    var afds = (Gee.Set<RoleFieldDetails>) get_abstract_field_details ();
    yield ((RoleDetails) this.persona).change_roles (afds);
  }
}

public class Contacts.OrgRole : BinChunkChild {

  public Role role { get; private set; default = new Role (); }

  public override bool is_empty {
    get { return this.role.is_empty (); }
  }

  public override string icon_name {
    get { return "building-symbolic"; }
  }

  public OrgRole () {
    this.parameters = new Gee.HashMultiMap<string, string> ();
  }

  public OrgRole.from_field_details (RoleFieldDetails role_field) {
    this.role = role_field.value;
    this.parameters = role_field.parameters;
  }

  protected override int compare_internal (BinChunkChild other)
      requires (other is OrgRole) {
    unowned var other_orgrole = (OrgRole) other;
    var orgs_cmp = strcmp (this.role.organisation_name,
                           other_orgrole.role.organisation_name);
    if (orgs_cmp != 0)
      return orgs_cmp;
    return strcmp (this.role.title, other_orgrole.role.title);
  }

  public override AbstractFieldDetails? create_afd () {
    if (this.is_empty)
      return null;

    return new RoleFieldDetails (this.role, this.parameters);
  }

  public override BinChunkChild copy () {
    var org_role = new OrgRole ();
    org_role.role.organisation_name = this.role.organisation_name;
    org_role.role.role = this.role.role;
    org_role.role.title = this.role.title;
    copy_parameters (org_role);
    return org_role;
  }

  protected override Variant? to_gvariant_internal () {
    return new Variant ("(ssv)",
                        this.role.organisation_name,
                        this.role.title,
                        parameters_to_gvariant ());
  }

  public override void apply_gvariant (Variant variant)
      requires (variant.get_type ().equal (new VariantType ("(ssv)"))) {

    string org, title;
    Variant params_variant;
    variant.get ("(ssv)", out org, out title, out params_variant);

    this.role.organisation_name = org;
    this.role.title = title;
    apply_gvariant_parameters (params_variant);
  }

  public string to_string () {
    if (this.role.title != "") {
      if (this.role.organisation_name != "") {
        // TRANSLATORS: "$ROLE at $ORGANISATION", e.g. "CEO at Linux Inc."
        return _("%s at %s").printf (this.role.title, this.role.organisation_name);
      }

      return this.role.title;
    }

    return this.role.organisation_name;
  }
}
