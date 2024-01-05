/*
 * Copyright © 2008 Alexander “weej” Jones <alex@weej.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#ifndef CHEESE_FLASH_H_
#define CHEESE_FLASH_H_

#include <gtk/gtk.h>
#include <glib-object.h>

G_BEGIN_DECLS

/**
 * CheeseFlash:
 *
 * Use the accessor functions below.
 */
struct _CheeseFlash
{
  /*< private >*/
  GtkWindow parent_instance;
  void *unused;
};

#define CHEESE_TYPE_FLASH (cheese_flash_get_type ())
G_DECLARE_FINAL_TYPE (CheeseFlash, cheese_flash, CHEESE, FLASH, GtkWindow)

CheeseFlash *cheese_flash_new (GtkWidget *parent);
void cheese_flash_fire (CheeseFlash *flash);

G_END_DECLS

#endif /* CHEESE_FLASH_H_ */
