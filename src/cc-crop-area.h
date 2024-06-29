/*
 * Copyright © 2009 Bastien Nocera <hadess@hadess.net>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#ifndef _CC_CROP_AREA_H_
#define _CC_CROP_AREA_H_

#include <glib-object.h>
#include <gtk/gtk.h>

G_BEGIN_DECLS

#define CC_TYPE_CROP_AREA (cc_crop_area_get_type ())
G_DECLARE_FINAL_TYPE (CcCropArea, cc_crop_area, CC, CROP_AREA, GtkWidget)

GtkWidget *      cc_crop_area_new                  (void);
GdkPaintable *   cc_crop_area_get_paintable        (CcCropArea   *area);
void             cc_crop_area_set_paintable        (CcCropArea   *area,
                                                    GdkPaintable *paintable);
void             cc_crop_area_set_min_size         (CcCropArea   *area,
                                                    int           width,
                                                    int           height);
GdkTexture *     cc_crop_area_create_texture       (CcCropArea   *area);

G_END_DECLS

#endif /* _CC_CROP_AREA_H_ */
