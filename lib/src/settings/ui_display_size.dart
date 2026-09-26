enum UiDisplaySize { normal, compact }

double workspaceNavigationExtent(UiDisplaySize size) => switch (size) {
  UiDisplaySize.normal => 48.0,
  UiDisplaySize.compact => 41.0,
};

double topHeaderHeight(UiDisplaySize size) => switch (size) {
  UiDisplaySize.normal => 44.0,
  UiDisplaySize.compact => 36.0,
};

double headerCapsuleHeight(UiDisplaySize size) => switch (size) {
  UiDisplaySize.normal => 30.0,
  UiDisplaySize.compact => 26.0,
};

double browserToolbarHeight(UiDisplaySize size) => switch (size) {
  UiDisplaySize.normal => 34.0,
  UiDisplaySize.compact => 30.0,
};
