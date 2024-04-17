#ifndef CG_CALIBRATION_H
#define CG_CALIBRATION_H

#include "config.h"

struct input_calibration_manager_v1;

struct input_calibration_manager_v1 *create_input_calibration(struct cg_seat *display);
void input_calibration_add(struct input_calibration_manager_v1 *manager, struct wlr_input_device *device);
void input_calibration_remove(struct input_calibration_manager_v1 *manager, struct wlr_input_device *device);


#endif // CG_CALIBRATION_H