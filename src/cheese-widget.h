/*
 * Copyright © 2009 Bastien Nocera <hadess@hadess.net>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#ifndef CHEESE_WIDGET_H_
#define CHEESE_WIDGET_H_

#include <glib-object.h>
#include <gtk/gtk.h>
#include <clutter/clutter.h>
#include <clutter-gtk/clutter-gtk.h>

G_BEGIN_DECLS

#define CHEESE_TYPE_WIDGET (cheese_widget_get_type ())
G_DECLARE_FINAL_TYPE (CheeseWidget, cheese_widget, CHEESE, WIDGET, GtkNotebook)

GtkWidget *cheese_widget_new (void);
void       cheese_widget_get_error (CheeseWidget *widget, GError **error);
GObject   *cheese_widget_get_camera (CheeseWidget *widget);
GtkWidget *cheese_widget_get_video_area (CheeseWidget *widget);


/**
 * CheeseWidgetState:
 * @CHEESE_WIDGET_STATE_NONE: Default state, camera uninitialized
 * @CHEESE_WIDGET_STATE_READY: The camera should be ready and the widget should be displaying the preview
 * @CHEESE_WIDGET_STATE_ERROR: An error occurred while setting up the camera, check what went wrong with cheese_widget_get_error()
 *
 * Current #CheeseWidget state.
 *
 */
typedef enum
{
  CHEESE_WIDGET_STATE_NONE,
  CHEESE_WIDGET_STATE_READY,
  CHEESE_WIDGET_STATE_ERROR
} CheeseWidgetState;

G_END_DECLS

#endif /* CHEESE_WIDGET_H_ */
