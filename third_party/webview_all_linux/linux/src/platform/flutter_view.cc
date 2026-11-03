#include "plugin/webview_all_linux_plugin_private.h"

#include <cstring>

namespace {

constexpr const gchar* kFlutterViewOverlayKey = "webview_all_linux_overlay";
constexpr const gchar *kFlutterInputWidgetKey =
    "webview_all_linux_flutter_input_widget";

GtkWidget *find_flutter_input_widget(GtkWidget *widget) {
  if (widget == nullptr) {
    return nullptr;
  }
  if (GTK_IS_EVENT_BOX(widget)) {
    return widget;
  }
  if (!GTK_IS_CONTAINER(widget)) {
    return nullptr;
  }

  GList *children = gtk_container_get_children(GTK_CONTAINER(widget));
  GtkWidget *result = nullptr;
  for (GList *item = children; item != nullptr && result == nullptr;
       item = item->next) {
    result = find_flutter_input_widget(GTK_WIDGET(item->data));
  }
  g_list_free(children);
  return result;
}

// Flutter registers Linux plugins after the runner realizes FlView. Reparenting
// FlView at that point destroys the GL surface used by the engine. Install the
// overlay inside FlView when the runner first parents it instead, which happens
// before realization in the standard Flutter runner.
gboolean flutter_view_parent_set_emission_hook(
    GSignalInvocationHint*,
    guint parameter_count,
    const GValue* parameters,
    gpointer) {
  if (parameter_count == 0) {
    return TRUE;
  }

  GObject* instance = G_OBJECT(g_value_get_object(&parameters[0]));
  if (instance == nullptr || !FL_IS_VIEW(instance)) {
    return TRUE;
  }

  GtkWidget* view_widget = GTK_WIDGET(instance);
  GtkWidget* parent = gtk_widget_get_parent(view_widget);
  if (parent != nullptr && GTK_IS_OVERLAY(parent)) {
    // Preserve runners that already wrap FlView in a GtkOverlay. The plugin
    // registration path will detect and reuse this parent.
    return TRUE;
  }
  if (g_object_get_data(instance, kFlutterViewOverlayKey) != nullptr) {
    return TRUE;
  }
  if (gtk_widget_get_realized(view_widget)) {
    g_warning(
        "webview_all_linux could not install its GtkOverlay before FlView "
        "was realized.");
    return TRUE;
  }

  GList* children = gtk_container_get_children(GTK_CONTAINER(view_widget));
  if (children == nullptr || children->next != nullptr) {
    g_warning(
        "webview_all_linux expected an unrealized FlView with one child.");
    g_list_free(children);
    return TRUE;
  }

  GtkWidget* flutter_content = GTK_WIDGET(children->data);
  g_object_ref(flutter_content);
  gtk_container_remove(GTK_CONTAINER(view_widget), flutter_content);

  GtkWidget* overlay = gtk_overlay_new();
  gtk_widget_set_hexpand(overlay, TRUE);
  gtk_widget_set_vexpand(overlay, TRUE);
  gtk_container_add(GTK_CONTAINER(overlay), flutter_content);
  gtk_container_add(GTK_CONTAINER(view_widget), overlay);
  gtk_widget_show(overlay);
  g_object_set_data_full(instance, kFlutterViewOverlayKey,
                         g_object_ref(overlay), g_object_unref);
  g_object_set_data_full(instance, kFlutterInputWidgetKey,
                         g_object_ref(flutter_content), g_object_unref);

  g_object_unref(flutter_content);
  g_list_free(children);
  return TRUE;
}

__attribute__((constructor)) void install_flutter_view_overlay_hook() {
  gpointer widget_class = g_type_class_ref(GTK_TYPE_WIDGET);
  const guint signal_id = g_signal_lookup("parent-set", GTK_TYPE_WIDGET);
  if (signal_id != 0) {
    g_signal_add_emission_hook(signal_id, 0,
                               flutter_view_parent_set_emission_hook, nullptr,
                               nullptr);
  }
  g_type_class_unref(widget_class);
}

}  // namespace

static void flutter_view_size_allocate_cb(GtkWidget* widget,
                                          GtkAllocation* allocation,
                                          gpointer user_data) {
  schedule_flutter_view_input_region_update(
      static_cast<WebviewAllLinuxPlugin *>(user_data));
}

static void flutter_view_layout_changed_cb(GtkWidget *widget,
                                           gpointer user_data) {
  schedule_flutter_view_input_region_update(
      static_cast<WebviewAllLinuxPlugin *>(user_data));
}

static void overlay_destroy_cb(GtkWidget *widget, gpointer user_data) {
  detach_linux_webview_host(static_cast<WebviewAllLinuxPlugin *>(user_data));
}

static LinuxWebView *webview_at_input_position(WebviewAllLinuxPlugin *self,
                                               gdouble x, gdouble y) {
  LinuxWebView *topmost = nullptr;
  GHashTableIter iter;
  gpointer key = nullptr;
  gpointer value = nullptr;
  g_hash_table_iter_init(&iter, self->webviews);
  while (g_hash_table_iter_next(&iter, &key, &value)) {
    LinuxWebView *webview = static_cast<LinuxWebView *>(value);
    if (webview == nullptr || !webview->visible ||
        webview->clip_width <= 0 || webview->clip_height <= 0 ||
        !gtk_widget_get_mapped(GTK_WIDGET(webview->web_view))) {
      continue;
    }
    if (x < webview->clip_x || y < webview->clip_y ||
        x >= webview->clip_x + webview->clip_width ||
        y >= webview->clip_y + webview->clip_height) {
      continue;
    }
    if (topmost == nullptr ||
        webview->frame_sequence > topmost->frame_sequence) {
      topmost = webview;
    }
  }
  return topmost;
}

static void forward_pointer_event(WebviewAllLinuxPlugin *self,
                                  GdkEvent *source_event) {
  if (self == nullptr || self->flutter_input_widget == nullptr ||
      self->disposing || source_event == nullptr) {
    return;
  }

  gdouble root_x = 0;
  gdouble root_y = 0;
  if (!gdk_event_get_root_coords(source_event, &root_x, &root_y)) {
    return;
  }
  GdkWindow *input_window = gtk_widget_get_window(self->flutter_input_widget);
  if (input_window == nullptr) {
    return;
  }
  gint input_x = 0;
  gint input_y = 0;
  gdk_window_get_origin(input_window, &input_x, &input_y);
  LinuxWebView *webview =
      webview_at_input_position(self, root_x - input_x, root_y - input_y);
  if (webview == nullptr) {
    return;
  }

  GtkWidget *webview_widget = GTK_WIDGET(webview->web_view);
  GdkWindow *webview_window = gtk_widget_get_window(webview_widget);
  if (webview_window == nullptr) {
    return;
  }
  gint webview_x = 0;
  gint webview_y = 0;
  gdk_window_get_origin(webview_window, &webview_x, &webview_y);

  GdkEvent *event = gdk_event_copy(source_event);
  // Retarget the real device event to WebKit. Synthetic events are ignored by
  // WebKit's page input handling even when GTK dispatch reaches the widget.
  event->any.send_event = FALSE;
  g_object_unref(event->any.window);
  event->any.window = GDK_WINDOW(g_object_ref(webview_window));
  if (event->type == GDK_MOTION_NOTIFY) {
    event->motion.x = root_x - webview_x;
    event->motion.y = root_y - webview_y;
  } else if (event->type == GDK_BUTTON_PRESS ||
             event->type == GDK_BUTTON_RELEASE ||
             event->type == GDK_2BUTTON_PRESS ||
             event->type == GDK_3BUTTON_PRESS) {
    event->button.x = root_x - webview_x;
    event->button.y = root_y - webview_y;
  }
  gtk_main_do_event(event);
  gdk_event_free(event);
}

static gboolean flutter_pointer_emission_hook(GSignalInvocationHint*,
                                              guint parameter_count,
                                              const GValue* parameters,
                                              gpointer user_data) {
  WebviewAllLinuxPlugin *self =
      static_cast<WebviewAllLinuxPlugin *>(user_data);
  if (self == nullptr || parameter_count < 2 ||
      self->flutter_input_widget == nullptr) {
    return TRUE;
  }
  GObject *instance = G_OBJECT(g_value_get_object(&parameters[0]));
  if (instance != G_OBJECT(self->flutter_input_widget)) {
    return TRUE;
  }
  GdkEvent *event =
      static_cast<GdkEvent *>(g_value_get_boxed(&parameters[1]));
  forward_pointer_event(self, event);
  return TRUE;
}

static void install_pointer_forwarding_hooks(
    WebviewAllLinuxPlugin *self) {
  if (self == nullptr || self->flutter_input_widget == nullptr ||
      self->button_press_hook_id != 0) {
    return;
  }
  const guint press_signal =
      g_signal_lookup("button-press-event", GTK_TYPE_WIDGET);
  const guint release_signal =
      g_signal_lookup("button-release-event", GTK_TYPE_WIDGET);
  const guint motion_signal =
      g_signal_lookup("motion-notify-event", GTK_TYPE_WIDGET);
  if (press_signal == 0 || release_signal == 0 || motion_signal == 0) {
    return;
  }
  self->button_press_hook_id = g_signal_add_emission_hook(
      press_signal, 0, flutter_pointer_emission_hook,
      g_object_ref(self), g_object_unref);
  self->button_release_hook_id = g_signal_add_emission_hook(
      release_signal, 0, flutter_pointer_emission_hook,
      g_object_ref(self), g_object_unref);
  self->motion_hook_id = g_signal_add_emission_hook(
      motion_signal, 0, flutter_pointer_emission_hook,
      g_object_ref(self), g_object_unref);
}

static void remove_pointer_forwarding_hooks(WebviewAllLinuxPlugin *self) {
  if (self == nullptr) {
    return;
  }
  if (self->button_press_hook_id != 0) {
    g_signal_remove_emission_hook(
        g_signal_lookup("button-press-event", GTK_TYPE_WIDGET),
        self->button_press_hook_id);
    self->button_press_hook_id = 0;
  }
  if (self->button_release_hook_id != 0) {
    g_signal_remove_emission_hook(
        g_signal_lookup("button-release-event", GTK_TYPE_WIDGET),
        self->button_release_hook_id);
    self->button_release_hook_id = 0;
  }
  if (self->motion_hook_id != 0) {
    g_signal_remove_emission_hook(
        g_signal_lookup("motion-notify-event", GTK_TYPE_WIDGET),
        self->motion_hook_id);
    self->motion_hook_id = 0;
  }
}

static gboolean overlay_get_child_position_cb(GtkOverlay *overlay,
                                              GtkWidget *widget,
                                              GtkAllocation *allocation,
                                              gpointer user_data) {
  LinuxWebView *webview = static_cast<LinuxWebView *>(
      g_object_get_data(G_OBJECT(widget), kLinuxWebViewInstanceKey));
  WebviewAllLinuxPlugin *self = static_cast<WebviewAllLinuxPlugin *>(user_data);
  if (webview == nullptr || webview->plugin != self) {
    return FALSE;
  }

  gint clip_x = webview->clip_x;
  gint clip_y = webview->clip_y;
  if (self->flutter_view != nullptr &&
      gtk_widget_get_parent(self->flutter_view) == GTK_WIDGET(overlay)) {
    GtkAllocation flutter_view_allocation;
    gtk_widget_get_allocation(self->flutter_view, &flutter_view_allocation);
    clip_x = static_cast<gint>(
        CLAMP(static_cast<gint64>(clip_x) + flutter_view_allocation.x,
              static_cast<gint64>(G_MININT), static_cast<gint64>(G_MAXINT)));
    clip_y = static_cast<gint>(
        CLAMP(static_cast<gint64>(clip_y) + flutter_view_allocation.y,
              static_cast<gint64>(G_MININT), static_cast<gint64>(G_MAXINT)));
  }

  allocation->x = clip_x;
  allocation->y = clip_y;
  allocation->width = webview->clip_width;
  allocation->height = webview->clip_height;
  return TRUE;
}

template <typename WidgetType>
static void clear_weak_widget_pointer(WidgetType **widget,
                                      WebviewAllLinuxPlugin *self) {
  if (*widget == nullptr) {
    return;
  }
  g_signal_handlers_disconnect_by_data(*widget, self);
  g_object_remove_weak_pointer(G_OBJECT(*widget),
                               reinterpret_cast<gpointer *>(widget));
  *widget = nullptr;
}

static void attach_linux_webview_host(WebviewAllLinuxPlugin *self,
                                      GtkWidget *view_widget,
                                      GtkOverlay *overlay,
                                      GtkWidget *input_widget) {
  if (self->flutter_view == view_widget && self->overlay == overlay &&
      self->flutter_input_widget == input_widget) {
    return;
  }

  detach_linux_webview_host(self);
  self->flutter_view = view_widget;
  self->overlay = overlay;
  self->flutter_input_widget = input_widget;
  if (self->flutter_input_widget == nullptr) {
    g_warning(
        "webview_all_linux could not locate Flutter's GTK input widget; "
        "native GtkOverlay routing will be used without changing any parent "
        "window input region.");
  }

  g_object_add_weak_pointer(G_OBJECT(self->flutter_view),
                            reinterpret_cast<gpointer *>(&self->flutter_view));
  g_object_add_weak_pointer(G_OBJECT(self->overlay),
                            reinterpret_cast<gpointer *>(&self->overlay));
  if (self->flutter_input_widget != nullptr) {
    g_object_add_weak_pointer(
        G_OBJECT(self->flutter_input_widget),
        reinterpret_cast<gpointer *>(&self->flutter_input_widget));
  }

  g_signal_connect(self->flutter_view, "size-allocate",
                   G_CALLBACK(flutter_view_size_allocate_cb), self);
  g_signal_connect(self->overlay, "size-allocate",
                   G_CALLBACK(flutter_view_size_allocate_cb), self);
  g_signal_connect(self->overlay, "get-child-position",
                   G_CALLBACK(overlay_get_child_position_cb), self);
  g_signal_connect(self->overlay, "destroy", G_CALLBACK(overlay_destroy_cb),
                   self);
  if (self->flutter_input_widget != nullptr) {
    g_signal_connect(self->flutter_input_widget, "size-allocate",
                     G_CALLBACK(flutter_view_size_allocate_cb), self);
    g_signal_connect(self->flutter_input_widget, "realize",
                     G_CALLBACK(flutter_view_layout_changed_cb), self);
    g_signal_connect(self->flutter_input_widget, "map",
                     G_CALLBACK(flutter_view_layout_changed_cb), self);
  }
  install_pointer_forwarding_hooks(self);
  schedule_flutter_view_input_region_update(self);
}

GtkOverlay* ensure_overlay(WebviewAllLinuxPlugin* self) {
  if (self->overlay != nullptr) {
    return self->overlay;
  }

  FlView* view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr) {
    return nullptr;
  }

  GtkWidget* view_widget = GTK_WIDGET(view);
  GtkOverlay* installed_overlay = GTK_OVERLAY(
      g_object_get_data(G_OBJECT(view_widget), kFlutterViewOverlayKey));
  if (installed_overlay != nullptr) {
    GtkWidget *input_widget = GTK_WIDGET(
        g_object_get_data(G_OBJECT(view_widget), kFlutterInputWidgetKey));
    if (input_widget == nullptr) {
      input_widget = find_flutter_input_widget(view_widget);
    }
    attach_linux_webview_host(self, view_widget, installed_overlay,
                              input_widget);
    return self->overlay;
  }

  GtkWidget* parent = gtk_widget_get_parent(view_widget);
  if (parent == nullptr) {
    return nullptr;
  }

  if (GTK_IS_OVERLAY(parent)) {
    attach_linux_webview_host(self, view_widget, GTK_OVERLAY(parent),
                              find_flutter_input_widget(view_widget));
    return self->overlay;
  }

  g_warning(
      "webview_all_linux requires its automatic GtkOverlay to be installed "
      "before FlView is realized.");
  return nullptr;
}

void update_flutter_view_input_region(WebviewAllLinuxPlugin* self) {
  if (self == nullptr || self->disposing ||
      self->flutter_input_widget == nullptr || self->overlay == nullptr) {
    return;
  }

  GtkWidget *input_widget = self->flutter_input_widget;
  if (!gtk_widget_get_realized(input_widget) ||
      !gtk_widget_get_has_window(input_widget) ||
      gtk_widget_get_window(input_widget) == nullptr) {
    return;
  }
  // Let Flutter receive pointer events over the native view, then forward the
  // real device events to WebKit. Some GTK backends do not preserve a click
  // when the Flutter window is shaped away from an overlapping native child.
  gtk_widget_input_shape_combine_region(input_widget, nullptr);
}

static gboolean update_flutter_view_input_region_idle_cb(gpointer user_data) {
  WebviewAllLinuxPlugin *self = static_cast<WebviewAllLinuxPlugin *>(user_data);
  self->input_region_update_source_id = 0;
  update_flutter_view_input_region(self);
  return G_SOURCE_REMOVE;
}

void schedule_flutter_view_input_region_update(WebviewAllLinuxPlugin *self) {
  if (self == nullptr || self->disposing ||
      self->input_region_update_source_id != 0) {
    return;
  }
  self->input_region_update_source_id = g_idle_add_full(
      G_PRIORITY_DEFAULT_IDLE, update_flutter_view_input_region_idle_cb,
      g_object_ref(self), g_object_unref);
}

void restore_flutter_view_input_region(WebviewAllLinuxPlugin *self) {
  if (self == nullptr || self->flutter_input_widget == nullptr ||
      !gtk_widget_get_realized(self->flutter_input_widget) ||
      !gtk_widget_get_has_window(self->flutter_input_widget)) {
    return;
  }
  gtk_widget_input_shape_combine_region(self->flutter_input_widget, nullptr);
}

void detach_linux_webview_host(WebviewAllLinuxPlugin *self) {
  if (self == nullptr) {
    return;
  }
  remove_pointer_forwarding_hooks(self);
  if (self->input_region_update_source_id != 0) {
    g_source_remove(self->input_region_update_source_id);
    self->input_region_update_source_id = 0;
  }
  restore_flutter_view_input_region(self);
  clear_weak_widget_pointer(&self->flutter_input_widget, self);
  clear_weak_widget_pointer(&self->flutter_view, self);
  clear_weak_widget_pointer(&self->overlay, self);
}

void release_linux_webview_focus(LinuxWebView *webview) {
  if (webview == nullptr || webview->web_view == nullptr ||
      webview->plugin == nullptr || webview->plugin->flutter_view == nullptr) {
    return;
  }
  GtkWidget *webview_widget = GTK_WIDGET(webview->web_view);
  GtkWidget *toplevel = gtk_widget_get_toplevel(webview_widget);
  if (toplevel == nullptr || !GTK_IS_WINDOW(toplevel)) {
    return;
  }
  GtkWidget *focus = gtk_window_get_focus(GTK_WINDOW(toplevel));
  if (focus == webview_widget ||
      (focus != nullptr && gtk_widget_is_ancestor(focus, webview_widget))) {
    gtk_widget_grab_focus(webview->plugin->flutter_view);
  }
}
