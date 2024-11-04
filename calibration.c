
#include <wayland-server-core.h>
#include <wayland-util.h>
#include <assert.h>

#include <wlr/util/log.h>

#include "output.h"
#include "seat.h"
#include "protocol/input_calibration.h"

#include "calibration.h"

static const struct ext_input_calibration_manager_v1_interface input_calibration_impl;
static const struct ext_input_device_v1_interface input_device_impl;

struct input_calibration_manager_v1 {
  struct wl_global *global;
  struct cg_seat *seat;

  // Internal state
  struct wl_list resources;
  struct wl_list devices; // input_device_v1::link

  struct wl_listener destroy;

  struct {
    struct wl_signal add;
		struct wl_signal done;
	} events;

  void* data;
};


struct input_device_v1 {
  struct input_calibration_manager_v1 *manager;
  struct wl_list link;

  // Internal state
  struct wlr_input_device *device;
  struct wl_list resources;

  
	struct wl_listener device_destroy;

  void* data;
};



static void manager_send_device(struct input_calibration_manager_v1 *manager,
	struct input_device_v1 *device, struct wl_resource *manager_resource);


static void manager_handle_destroy(struct wl_client *client,
		struct wl_resource *manager_resource) {
	wl_resource_destroy(manager_resource);
}

static const struct ext_input_calibration_manager_v1_interface input_calibration_impl = {
	.destroy = manager_handle_destroy,
};


static void manager_handle_resource_destroy(struct wl_resource *resource) {
	wl_list_remove(wl_resource_get_link(resource));
}

static void input_calibration_bind(struct wl_client *wl_client, void *data,
		uint32_t version, uint32_t id) {
	struct input_calibration_manager_v1 *manager = data;

	struct wl_resource *manager_resource  = wl_resource_create(wl_client,
		&ext_input_calibration_manager_v1_interface, version, id);
	if (!manager_resource) {
		wl_client_post_no_memory(wl_client);
		return;
	}

	wl_resource_set_implementation(manager_resource, &input_calibration_impl,
		manager, manager_handle_resource_destroy);


	wl_list_insert(&manager->resources, wl_resource_get_link(manager_resource));
	struct input_device_v1 *device;
	wl_list_for_each(device, &manager->devices, link) {
		manager_send_device(manager, device, manager_resource);
	}

	ext_input_calibration_manager_v1_send_done(manager_resource);
}


struct input_calibration_manager_v1 *create_input_calibration(struct cg_seat *seat){
  struct input_calibration_manager_v1  *manager = calloc(1, sizeof(struct input_calibration_manager_v1));
  if (!manager) {
    wlr_log(WLR_ERROR, "Failed to allocate input_calibration");
    return NULL;
  }


  wl_list_init(&manager->devices);
  wl_list_init(&manager->resources);
  wl_signal_init(&manager->events.add);
  wl_signal_init(&manager->events.done);

  manager->seat = seat;
  manager->global = wl_global_create(seat->server->wl_display, &ext_input_calibration_manager_v1_interface, 1, manager, input_calibration_bind);

  return manager;
}

static void input_device_destroy(struct input_device_v1 *device) {
  if(device == NULL) return;
  struct wl_resource *resource, *tmp;
  wl_resource_for_each_safe(resource, tmp, &device->resources) {
    ext_input_device_v1_send_removed(resource);
		wl_list_remove(wl_resource_get_link(resource));
    wl_list_init(wl_resource_get_link(resource));
		wl_resource_set_user_data(resource, NULL);
  }
  wl_list_remove(&device->link);
  wl_list_remove(&device->device_destroy.link);
  free(device);
}

static void input_handle_device_destroy(struct wl_listener *listener,
		void *data){
      struct input_device_v1 *device = wl_container_of(listener, device, device_destroy);
      input_device_destroy(device);
}



void input_calibration_add(struct input_calibration_manager_v1 *manager, struct wlr_input_device *device){
  struct input_device_v1 *input_dev = calloc(1, sizeof(struct input_device_v1));
  if (!input_dev) {
    wlr_log(WLR_ERROR, "Failed to allocate input_device");
    return;
  }

  input_dev->manager = manager;
  input_dev->device = device; 

  wl_list_init(&input_dev->resources);
  wl_list_insert(&manager->devices, &input_dev->link);

  input_dev->device_destroy.notify = input_handle_device_destroy;
  wl_signal_add(&device->events.destroy, &input_dev->device_destroy);
  struct wl_resource *resource;
  wl_list_for_each(resource, &manager->resources, link) {
		manager_send_device(manager, input_dev, resource);
    ext_input_calibration_manager_v1_send_done(resource);
	}
}


static void input_device_resource_destroy(struct wl_resource *resource) {
	wl_list_remove(wl_resource_get_link(resource));
}


static void handle_release(struct wl_client *client,
		struct wl_resource *resource) {
	wl_resource_destroy(resource);
}


static void handle_map_to_region(struct wl_client *client, struct wl_resource *resource,
    int32_t x, int32_t y, int32_t width, int32_t height) {

  assert(wl_resource_instance_of(resource,
		&ext_input_device_v1_interface, &input_device_impl));
  struct input_device_v1 *input_device = wl_resource_get_user_data(resource);
  struct cg_seat *seat = input_device->manager->seat;

  wlr_log(WLR_INFO, "input_device %s map_to_region %dx%d+%d+%d", input_device->device->name, width, height, x, y);
	struct wlr_box box = { .x = x, .y = y, .width=width, .height=height };
	wlr_cursor_map_input_to_output(seat->cursor, input_device->device, NULL);
	wlr_cursor_map_input_to_region(seat->cursor, input_device->device, &box);
}


static void handle_map_to_output(struct wl_client *client, struct wl_resource *resource,
    const char *output_name) {

  assert(wl_resource_instance_of(resource,
		&ext_input_device_v1_interface, &input_device_impl));
  struct input_device_v1 *input_device = wl_resource_get_user_data(resource);
  struct cg_seat *seat = input_device->manager->seat;
	struct cg_output *output;
  wl_list_for_each (output, &seat->server->outputs, link) {
		if (strcmp(output_name, output->wlr_output->name) == 0) {
			wlr_log(WLR_INFO, "input device %s map to output device %s\n", input_device->device->name,
				output->wlr_output->name);
			wlr_cursor_map_input_to_output(seat->cursor, input_device->device, output->wlr_output);
	    wlr_cursor_map_input_to_region(seat->cursor, input_device->device, NULL);
			return;
		}
	}
  wl_resource_post_error(resource,
			EXT_INPUT_DEVICE_V1_ERROR_NO_SUCH_OUTPUT,
			"Requested output does not exist");
}


static const struct ext_input_device_v1_interface input_device_impl = {
  .map_to_region = handle_map_to_region,
  .map_to_output = handle_map_to_output,
  .release = handle_release,
};

static void manager_send_device(struct input_calibration_manager_v1 *manager,
	struct input_device_v1 *input_device, struct wl_resource *manager_resource){

	struct wl_client *client = wl_resource_get_client(manager_resource);
	uint32_t version = wl_resource_get_version(manager_resource);
  struct wl_resource *device_resource = wl_resource_create(client,
		&ext_input_device_v1_interface, version, 0);
	if (device_resource == NULL) {
		wl_resource_post_no_memory(manager_resource);
		return;
	}

  wl_resource_set_implementation(device_resource, &input_device_impl, input_device,
		input_device_resource_destroy);
	wl_list_insert(&input_device->resources, wl_resource_get_link(device_resource));


  ext_input_calibration_manager_v1_send_add(manager_resource, device_resource);

  ext_input_device_v1_send_name(device_resource, input_device->device->name);
  ext_input_device_v1_send_type(device_resource, input_device->device->type);

}