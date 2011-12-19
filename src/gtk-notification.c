/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * gtk-notification.c
 * Copyright (C) Erick Pérez Castellanos 2011 <erick.red@gmail.com>
 *
 gtk-notification.c is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * gtk-notification.c is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.";
 */

#include "gtk-notification.h"

/**
 * SECTION:gtknotification
 * @short_description: Report notification messages to the user
 * @include: gtk/gtk.h
 * @see_also: #GtkStatusbar, #GtkMessageDialog, #GtkInfoBar
 *
 * #GtkNotification is a widget made for showing notifications to
 * the user, allowing them to execute 1 action over the notification,
 * or closing it.
 *
 * #GtkNotification provides one signal (#GtkNotification::actioned), for when the action button is activated.
 * Here the user will receive the signal, and then it's up to the user to destroy the widget,
 * or hide it.
 * The close button destroy the notification, so you can safely connect to the
 * #GtkWidget::destroy signal in order to know when the notification has been closed.
 *
 * #GtkNotification, the main difference here with some other widgets, is the timeout
 * inside GtkNotification widget. It mean, when the no action is taken over a period of time,
 * The widget will destroy itself.
 *
 */

#define GTK_PARAM_READWRITE G_PARAM_READWRITE|G_PARAM_STATIC_NAME|G_PARAM_STATIC_NICK|G_PARAM_STATIC_BLURB
#define SHADOW_OFFSET_X 4
#define SHADOW_OFFSET_Y 6

enum {
	PROP_0,
	PROP_MESSAGE,
	PROP_BUTTON_LABEL,
	PROP_TIMEOUT
};

struct _GtkNotificationPrivate {
	GtkWidget *message;
	GtkWidget *action_button;
	GtkWidget *close_button;

	gchar * message_label;
	gchar * button_label;
	guint timeout;

	guint timeout_source_id;
};

enum {
	ACTIONED,
	LAST_SIGNAL
};

static guint notification_signals[LAST_SIGNAL] = { 0 };

static void draw_shadow_box(cairo_t *cr, GdkRectangle rect, double radius, double transparency);
static gboolean gtk_notification_draw(GtkWidget *widget, cairo_t *cr);
static void gtk_notification_get_preferred_width(GtkWidget *widget, gint *minimum_size, gint *natural_size);
static void gtk_notification_get_preferred_height_for_width(GtkWidget *widget,
		gint width,
		gint *minimum_height,
		gint *natural_height);
static void gtk_notification_get_preferred_height(GtkWidget *widget, gint *minimum_size, gint *natural_size);
static void gtk_notification_get_preferred_width_for_height(GtkWidget *widget,
		gint height,
		gint *minimum_width,
		gint *natural_width);
static void gtk_notification_size_allocate(GtkWidget *widget, GtkAllocation *allocation);
static void gtk_notification_update_message(GtkNotification * notification, const gchar * new_message);
static void gtk_notification_update_button(GtkNotification * notification, const gchar * new_button_label);
static gboolean gtk_notification_auto_destroy(gpointer user_data);

/* signals handlers */
static void gtk_notification_close_button_clicked_cb(GtkWidget * widget, gpointer user_data);
static void gtk_notification_action_button_clicked_cb(GtkWidget * widget, gpointer user_data);

G_DEFINE_TYPE(GtkNotification, gtk_notification, GTK_TYPE_BOX);

static void
gtk_notification_init(GtkNotification *notification)
{
	g_object_set(GTK_BOX(notification), "orientation", GTK_ORIENTATION_HORIZONTAL, "homogeneous", FALSE, "spacing", 2, "margin-bottom", 5, NULL);

	gtk_style_context_add_class(gtk_widget_get_style_context(GTK_WIDGET(notification)), "contacts-notification");

	//FIXME position should be set by properties
	gtk_widget_set_halign(GTK_WIDGET(notification), GTK_ALIGN_CENTER);
	gtk_widget_set_valign(GTK_WIDGET(notification), GTK_ALIGN_START);

	gtk_widget_push_composite_child();

	notification->priv = G_TYPE_INSTANCE_GET_PRIVATE (notification,
			GTK_TYPE_NOTIFICATION,
			GtkNotificationPrivate);

	notification->priv->message = gtk_label_new(notification->priv->message_label);
	gtk_widget_show(notification->priv->message);
	notification->priv->action_button = gtk_button_new_with_label(notification->priv->button_label);
	gtk_widget_show(notification->priv->action_button);
	g_signal_connect(notification->priv->action_button,
			"clicked",
			G_CALLBACK(gtk_notification_action_button_clicked_cb),
			notification);

	notification->priv->close_button = gtk_button_new();
	gtk_button_set_relief (GTK_BUTTON (notification->priv->close_button), GTK_RELIEF_NONE);
	gtk_widget_show(notification->priv->close_button);
	g_object_set(notification->priv->close_button, "relief", GTK_RELIEF_NONE, "focus-on-click", FALSE, NULL);
	g_signal_connect(notification->priv->close_button,
			"clicked",
			G_CALLBACK(gtk_notification_close_button_clicked_cb),
			notification);
	GtkWidget * close_button_image = gtk_image_new_from_icon_name("window-close-symbolic", GTK_ICON_SIZE_BUTTON);
	gtk_button_set_image(GTK_BUTTON(notification->priv->close_button), close_button_image);

	gtk_box_pack_start(GTK_BOX(notification), notification->priv->message, FALSE, FALSE, 8);
	gtk_box_pack_end(GTK_BOX(notification), notification->priv->close_button, FALSE, TRUE, 0);
	gtk_box_pack_end(GTK_BOX(notification), notification->priv->action_button, FALSE, TRUE, 0);

	gtk_widget_pop_composite_child();

	notification->priv->timeout_source_id = 0;
}

static void
gtk_notification_finalize (GObject *object)
{
	g_return_if_fail(GTK_IS_NOTIFICATION (object));
	GtkNotification * notification = GTK_NOTIFICATION(object);

	if (notification->priv->message_label) {
		g_free(notification->priv->message_label);
	}
	if (notification->priv->button_label) {
		g_free(notification->priv->button_label);
	}
	if (notification->priv->timeout_source_id != 0) {
		g_source_remove(notification->priv->timeout_source_id);
	}

	G_OBJECT_CLASS (gtk_notification_parent_class)->finalize(object);
}

static void
gtk_notification_set_property (GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec)
{
	g_return_if_fail(GTK_IS_NOTIFICATION (object));
	GtkNotification * notification = GTK_NOTIFICATION(object);

	switch (prop_id) {
	case PROP_MESSAGE:
		gtk_notification_update_message(notification, g_value_get_string(value));
		break;
	case PROP_BUTTON_LABEL:
		gtk_notification_update_button(notification, g_value_get_string(value));
		break;
	case PROP_TIMEOUT:
		notification->priv->timeout = g_value_get_uint(value);
		g_object_notify(object, "timeout");
		break;
	default:
		G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
		break;
	}
}

static void
gtk_notification_get_property (GObject *object, guint prop_id, GValue *value, GParamSpec *pspec)
{
	g_return_if_fail(GTK_IS_NOTIFICATION (object));
	GtkNotification * notification = GTK_NOTIFICATION(object);

	switch (prop_id) {
	case PROP_MESSAGE:
		g_value_set_string(value, notification->priv->message_label);
		break;
	case PROP_BUTTON_LABEL:
		g_value_set_string(value, notification->priv->button_label);
		break;
	case PROP_TIMEOUT:
		g_value_set_uint(value, notification->priv->timeout);
		break;
	default:
		G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
		break;
	}
}

static void
gtk_notification_class_init (GtkNotificationClass *klass)
{
	GObjectClass* object_class = G_OBJECT_CLASS (klass);
	GtkWidgetClass* widget_class = GTK_WIDGET_CLASS(klass);

	object_class->finalize = gtk_notification_finalize;
	object_class->set_property = gtk_notification_set_property;
	object_class->get_property = gtk_notification_get_property;

	widget_class->get_preferred_width = gtk_notification_get_preferred_width;
	widget_class->get_preferred_height_for_width = gtk_notification_get_preferred_height_for_width;
	widget_class->get_preferred_height = gtk_notification_get_preferred_height;
	widget_class->get_preferred_width_for_height = gtk_notification_get_preferred_width_for_height;
	widget_class->size_allocate = gtk_notification_size_allocate;

	widget_class->draw = gtk_notification_draw;

	//FIXME these properties need tranlsations
	/**
	 * GtkNotification:message:
	 *
	 * Message shown in the notification.
	 *
	 * Since: 0.1
	 */
	g_object_class_install_property(object_class,
			PROP_MESSAGE,
			g_param_spec_string("message", "message", "Message shown on the notification", "",
			GTK_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	/**
	 * GtkNotification:button-label:
	 *
	 * Action button label, could be one of #GtkStockItem.
	 *
	 * Since: 0.1
	 */
	g_object_class_install_property(object_class,
			PROP_BUTTON_LABEL,
			g_param_spec_string("button-label",
					"button-label",
					"Label of the action button, if is a stock gtk indetifier, the button will get and icon too",
					"",
					GTK_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	/**
	 * GtkNotification:timeout:
	 *
	 * The time it takes to hide the widget, in seconds.
	 *
	 * Since: 0.1
	 */
	g_object_class_install_property(object_class,
			PROP_TIMEOUT,
			g_param_spec_uint("timeout", "timeout", "The time it takes to hide the widget, in seconds", 0, G_MAXUINT, 5,
			GTK_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	notification_signals[ACTIONED] = g_signal_new("actioned",
			G_OBJECT_CLASS_TYPE (klass),
			G_SIGNAL_RUN_LAST,
			G_STRUCT_OFFSET (GtkNotificationClass, actioned),
			NULL,
			NULL,
			g_cclosure_marshal_VOID__VOID,
			G_TYPE_NONE,
			0);

	g_type_class_add_private(object_class, sizeof(GtkNotificationPrivate));
}

static void
draw_shadow_box (cairo_t *cr, GdkRectangle rect, double radius, double transparency)
{
	cairo_pattern_t *pattern;
	double x0, x1, x2, x3;
	double y0, y1, y2, y3;

	x0 = rect.x;
	x1 = rect.x + radius;
	x2 = rect.x + rect.width - radius;
	x3 = rect.x + rect.width;

	y0 = rect.y;
	y2 = rect.y + rect.height - radius;
	y3 = rect.y + rect.height;

	/* Fill non-border part */
	cairo_set_source_rgba(cr, 0, 0, 0, transparency);
	cairo_rectangle(cr, x1, y0, x2 - x1, y2 - y0);
	cairo_fill(cr);

	/* Bottom border */

	pattern = cairo_pattern_create_linear(0, y2, 0, y3);

	cairo_pattern_add_color_stop_rgba(pattern, 0.0, 0.0, 0, 0, transparency);
	cairo_pattern_add_color_stop_rgba(pattern, 1.0, 0.0, 0, 0, 0.0);

	cairo_set_source(cr, pattern);
	cairo_pattern_destroy(pattern);

	cairo_rectangle(cr, x1, y2, x2 - x1, y3 - y2);
	cairo_fill(cr);

	/* Left border */

	pattern = cairo_pattern_create_linear(x0, 0, x1, 0);

	cairo_pattern_add_color_stop_rgba(pattern, 0.0, 0.0, 0, 0, 0.0);
	cairo_pattern_add_color_stop_rgba(pattern, 1.0, 0.0, 0, 0, transparency);

	cairo_set_source(cr, pattern);
	cairo_pattern_destroy(pattern);

	cairo_rectangle(cr, x0, y0, x1 - x0, y2 - y0);
	cairo_fill(cr);

	/* Right border */

	pattern = cairo_pattern_create_linear(x2, 0, x3, 0);

	cairo_pattern_add_color_stop_rgba(pattern, 0.0, 0.0, 0, 0, transparency);
	cairo_pattern_add_color_stop_rgba(pattern, 1.0, 0.0, 0, 0, 0.0);

	cairo_set_source(cr, pattern);
	cairo_pattern_destroy(pattern);

	cairo_rectangle(cr, x2, y0, x3 - x2, y2 - y0);
	cairo_fill(cr);

	/* SW corner */

	pattern = cairo_pattern_create_radial(x1, y2, 0, x1, y2, radius);

	cairo_pattern_add_color_stop_rgba(pattern, 0.0, 0.0, 0, 0, transparency);
	cairo_pattern_add_color_stop_rgba(pattern, 1.0, 0.0, 0, 0, 0.0);

	cairo_set_source(cr, pattern);
	cairo_pattern_destroy(pattern);

	cairo_rectangle(cr, x0, y2, x1 - x0, y3 - y2);
	cairo_fill(cr);

	/* SE corner */

	pattern = cairo_pattern_create_radial(x2, y2, 0, x2, y2, radius);

	cairo_pattern_add_color_stop_rgba(pattern, 0.0, 0.0, 0, 0, transparency);
	cairo_pattern_add_color_stop_rgba(pattern, 1.0, 0.0, 0, 0, 0.0);

	cairo_set_source(cr, pattern);
	cairo_pattern_destroy(pattern);

	cairo_rectangle(cr, x2, y2, x3 - x2, y3 - y2);
	cairo_fill(cr);
}

static gboolean
gtk_notification_draw (GtkWidget *widget, cairo_t *cr)
{
	GtkStyleContext *context;
	GdkRectangle rect;
	int border_radius;
	GtkStateFlags state;

	gtk_widget_get_allocation (widget, &rect);

	context = gtk_widget_get_style_context(widget);
	state = gtk_style_context_get_state (context);

	border_radius = SHADOW_OFFSET_Y; /* TODO: Should pick this up from context */

	draw_shadow_box (cr, rect, border_radius, 0.3);

	gtk_style_context_save (context);
	//FIXME I don't see the frame drawing at all
	gtk_render_background (context,  cr,
						   SHADOW_OFFSET_X, 0,
						   gtk_widget_get_allocated_width (widget) - 2 *SHADOW_OFFSET_X,
						   gtk_widget_get_allocated_height (widget) - SHADOW_OFFSET_Y);
	gtk_render_frame (context,cr,
					  SHADOW_OFFSET_X, 0,
					  gtk_widget_get_allocated_width (widget) - 2 *SHADOW_OFFSET_X,
					  gtk_widget_get_allocated_height (widget) - SHADOW_OFFSET_Y);

	gtk_style_context_restore (context);

	if (GTK_WIDGET_CLASS(gtk_notification_parent_class)->draw)
		GTK_WIDGET_CLASS(gtk_notification_parent_class)->draw(widget, cr);

	/* starting timeout when drawing the first time */
	GtkNotification * notification = GTK_NOTIFICATION(widget);
	if (notification->priv->timeout_source_id == 0) {
		notification->priv->timeout_source_id = g_timeout_add(notification->priv->timeout * 1000,
				gtk_notification_auto_destroy,
				widget);
	}
	return FALSE;
}

static void
gtk_notification_get_preferred_width (GtkWidget *widget, gint *minimum_size, gint *natural_size)
{
	gint parent_minimum_size, parent_natural_size;

	GTK_WIDGET_CLASS(gtk_notification_parent_class)->
		get_preferred_width (widget, &parent_minimum_size, &parent_natural_size);

	*minimum_size = parent_minimum_size + SHADOW_OFFSET_X * 2 + 2*2;
	*natural_size = parent_natural_size + SHADOW_OFFSET_X * 2 + 2*2;
}

static void
gtk_notification_get_preferred_height_for_width (GtkWidget *widget,
												 gint width,
												 gint *minimum_height,
												 gint *natural_height)
{
	gint parent_minimum_size, parent_natural_size;

	GTK_WIDGET_CLASS(gtk_notification_parent_class)->
		get_preferred_height_for_width (widget,
										width,
										&parent_minimum_size,
										&parent_natural_size);

	*minimum_height = parent_minimum_size + SHADOW_OFFSET_Y;
	*natural_height = parent_natural_size + SHADOW_OFFSET_Y;
}

static void
gtk_notification_get_preferred_height (GtkWidget *widget, gint *minimum_size, gint *natural_size)
{
	gint parent_minimum_size, parent_natural_size;

	GTK_WIDGET_CLASS(gtk_notification_parent_class)->get_preferred_height(widget, &parent_minimum_size, &parent_natural_size);

	*minimum_size = parent_minimum_size + SHADOW_OFFSET_Y + 2;
	*natural_size = parent_natural_size + SHADOW_OFFSET_Y + 2;
}

static void
gtk_notification_get_preferred_width_for_height (GtkWidget *widget,
												 gint height,
												 gint *minimum_width,
												 gint *natural_width) {
	gint parent_minimum_size, parent_natural_size;

	GTK_WIDGET_CLASS(gtk_notification_parent_class)->
		get_preferred_width_for_height(widget,
									   height,
									   &parent_minimum_size,
									   &parent_natural_size);

	*minimum_width = parent_minimum_size + 2 * SHADOW_OFFSET_X + 2*2;
	*natural_width = parent_natural_size + 2 * SHADOW_OFFSET_X + 2*2;
}

static void
gtk_notification_size_allocate (GtkWidget *widget, GtkAllocation *allocation)
{
	GtkAllocation parent_allocation;

	parent_allocation.x = allocation->x + SHADOW_OFFSET_X + 2;
	parent_allocation.y = allocation->y;
	parent_allocation.width = allocation->width - 2 * SHADOW_OFFSET_X - 2*2;
	parent_allocation.height = allocation->height - SHADOW_OFFSET_Y - 2;

	GTK_WIDGET_CLASS(gtk_notification_parent_class)->
		size_allocate (widget, &parent_allocation);

	gtk_widget_set_allocation (widget, allocation);
}

static void
gtk_notification_update_message (GtkNotification * notification, const gchar * new_message)
{
	g_free(notification->priv->message_label);
	notification->priv->message_label = g_strdup(new_message);
	g_object_notify(G_OBJECT(notification), "message");

	gtk_label_set_text(GTK_LABEL(notification->priv->message), notification->priv->message_label);
}

static void
gtk_notification_update_button (GtkNotification * notification, const gchar * new_button_label)
{
	g_free(notification->priv->button_label);
	notification->priv->button_label = g_strdup(new_button_label);
	g_object_notify(G_OBJECT(notification), "button-label");

	gtk_button_set_label(GTK_BUTTON(notification->priv->action_button), notification->priv->button_label);
	gtk_button_set_use_stock(GTK_BUTTON(notification->priv->action_button), TRUE);
}

static gboolean
gtk_notification_auto_destroy (gpointer user_data)
{
	GtkWidget * notification = GTK_WIDGET(user_data);
	gtk_widget_destroy(notification);
	return FALSE;
}

static void
gtk_notification_close_button_clicked_cb (GtkWidget * widget, gpointer user_data)
{
	GtkNotification * notification = GTK_NOTIFICATION(user_data);
	g_source_remove(notification->priv->timeout_source_id);
	notification->priv->timeout_source_id = 0;

	gtk_widget_destroy(GTK_WIDGET(notification));
}

static void
gtk_notification_action_button_clicked_cb (GtkWidget * widget, gpointer user_data)
{
	g_signal_emit_by_name(user_data, "actioned", NULL);
}

GtkWidget *
gtk_notification_new(gchar * message, gchar * action)
{
	return g_object_new(GTK_TYPE_NOTIFICATION, "message", message, "button-label", action, NULL);
}
