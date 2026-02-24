{ ... }:

let
  c = "cosmic";
  themeBuilder = "${c}/com.system76.CosmicTheme.Dark.Builder/v1";
  tk = "${c}/com.system76.CosmicTk/v1";
  panel = "${c}/com.system76.CosmicPanel.Panel/v1";
  dock = "${c}/com.system76.CosmicPanel.Dock/v1";
  comp = "${c}/com.system76.CosmicComp/v1";
  bg = "${c}/com.system76.CosmicBackground/v1";
  term = "${c}/com.system76.CosmicTerm/v1";
  idle = "${c}/com.system76.CosmicIdle/v1";
  files = "${c}/com.system76.CosmicFiles/v1";
  appList = "${c}/com.system76.CosmicAppList/v1";
  portal = "${c}/com.system76.CosmicPortal/v1";
  wallpaper = "${c}/com.system76.CosmicSettings.Wallpaper/v1";
  panelEntries = "${c}/com.system76.CosmicPanel/v1";
in
{
  xdg.configFile = {

    # ── Theme — hot pink accent, pure black background ──────────────────

    "${themeBuilder}/accent".text = ''
      Some((
          red: 1.0,
          green: 0.0,
          blue: 0.8666501,
      ))'';

    "${themeBuilder}/bg_color".text = ''
      Some((
          red: 0.0,
          green: 0.0,
          blue: 0.0,
          alpha: 1.0,
      ))'';

    # Default: standard corner radii and spacing.
    # "${themeBuilder}/corner_radii".text = "(radius_0: (0.0,0.0,0.0,0.0), radius_xs: (4.0,4.0,4.0,4.0), radius_s: (8.0,8.0,8.0,8.0), radius_m: (16.0,16.0,16.0,16.0), radius_l: (32.0,32.0,32.0,32.0), radius_xl: (160.0,160.0,160.0,160.0))";
    # "${themeBuilder}/spacing".text = "(space_none: 0, space_xxxs: 4, space_xxs: 4, space_xs: 8, space_s: 8, space_m: 16, space_l: 24, space_xl: 32, space_xxl: 48, space_xxxl: 64)";

    # ── Toolkit — compact UI, Inter + Source Code Pro ────────────────────

    "${tk}/header_size".text = "Compact";
    "${tk}/interface_density".text = "Compact";
    "${tk}/show_minimize".text = "true";

    "${tk}/interface_font".text = ''
      (
          family: "Inter",
          weight: Normal,
          stretch: Normal,
          style: Normal,
      )'';

    "${tk}/monospace_font".text = ''
      (
          family: "Source Code Pro",
          weight: Normal,
          stretch: Normal,
          style: Normal,
      )'';

    # ── Panel — small, top, stripped empty ───────────────────────────────

    # Default: "${panelEntries}/entries".text = "[\"Panel\", \"Dock\"]";
    # Default: "${panel}/name".text = "\"Panel\"";
    # Default: "${panel}/anchor".text = "Top";
    "${panel}/size".text = "S";
    # Default: "${panel}/layer".text = "Top";
    # Default: "${panel}/background".text = "ThemeDefault";
    # Default: "${panel}/keyboard_interactivity".text = "OnDemand";
    # Default: "${panel}/expand_to_edges".text = "false";
    # Default: "${panel}/padding_overlap".text = "0.5";
    # Default: "${panel}/padding".text = "0";
    # Default: "${panel}/opacity".text = "1.0";
    # Default: "${panel}/output".text = "All";
    # Default: "${panel}/anchor_gap".text = "false";
    # Default: "${panel}/margin".text = "0";
    # Default: "${panel}/spacing".text = "0";
    # Default: "${panel}/size_wings".text = "None";
    # Default: "${panel}/size_center".text = "None";
    # Default: "${panel}/border_radius".text = "12";
    # Default: "${panel}/exclusive_zone".text = "true";
    # Default: "${panel}/autohover_delay_ms".text = "Some(500)";
    # Default: "${panel}/autohide".text = "None";
    "${panel}/plugins_center".text = "Some([])";
    "${panel}/plugins_wings".text = "Some(([], []))";

    # ── Dock — small, edge-to-edge, no rounded corners ──────────────────

    # Default: "${dock}/name".text = "\"Dock\"";
    # Default: "${dock}/anchor".text = "Bottom";
    "${dock}/size".text = "S";
    # Default: "${dock}/layer".text = "Top";
    # Default: "${dock}/background".text = "ThemeDefault";
    # Default: "${dock}/keyboard_interactivity".text = "OnDemand";
    "${dock}/expand_to_edges".text = "true";
    # Default: "${dock}/padding_overlap".text = "0.5";
    "${dock}/padding".text = "4";
    # Default: "${dock}/opacity".text = "1.0";
    # Default: "${dock}/output".text = "All";
    # Default: "${dock}/anchor_gap".text = "false";
    # Default: "${dock}/margin".text = "0";
    # Default: "${dock}/spacing".text = "0";
    # Default: "${dock}/size_wings".text = "None";
    # Default: "${dock}/size_center".text = "None";
    "${dock}/border_radius".text = "0";
    # Default: "${dock}/exclusive_zone".text = "true";
    # Default: "${dock}/autohover_delay_ms".text = "Some(500)";
    # Default: "${dock}/autohide".text = "None";

    "${dock}/plugins_center".text = ''
      Some([
          "com.system76.CosmicAppList",
          "com.system76.CosmicAppletMinimize",
      ])'';

    "${dock}/plugins_wings".text = ''
      Some(([
          "com.system76.CosmicPanelAppButton",
          "com.system76.CosmicAppletWorkspaces",
      ], [
          "com.system76.CosmicAppletStatusArea",
          "com.system76.CosmicAppletTiling",
          "com.system76.CosmicAppletNetwork",
          "com.system76.CosmicAppletBluetooth",
          "com.system76.CosmicAppletAudio",
          "com.system76.CosmicAppletTime",
          "com.system76.CosmicAppletBattery",
          "com.system76.CosmicAppletNotifications",
          "com.system76.CosmicAppletPower",
      ]))'';

    # ── Dock favorites ──────────────────────────────────────────────────

    "${appList}/favorites".text = ''
      [
          "com.system76.CosmicFiles",
          "com.system76.CosmicTerm",
          "google-chrome",
          "Code",
      ]'';
    # Default: "${appList}/enable_drag_source".text = "true";
    # Default: "${appList}/filter_top_levels".text = "None";

    # ── Compositor — flat accel, ctrl+alt+bksp, autotile ────────────────

    "${comp}/input_default".text = ''
      (
          state: Enabled,
          acceleration: Some((
              profile: Some(Flat),
              speed: -0.032175081318059684,
          )),
      )'';

    "${comp}/xkb_config".text = ''
      (
          rules: "",
          model: "pc104",
          layout: "us",
          variant: "",
          options: Some("terminate:ctrl_alt_bksp"),
          repeat_delay: 600,
          repeat_rate: 25,
      )'';

    "${comp}/autotile_behavior".text = "PerWorkspace";
    "${comp}/active_hint".text = "true";
    # Default: "${comp}/edge_snap_threshold".text = "10";
    # Default: "${comp}/workspaces".text = "(workspace_mode: Global, workspace_layout: Horizontal)";

    # ── Background — solid black ────────────────────────────────────────

    "${bg}/same-on-all".text = "true";

    "${bg}/all".text = ''
      (
          output: "all",
          source: Color(Single((0.0, 0.0, 0.0))),
          filter_by_theme: false,
          rotation_frequency: 900,
          filter_method: Lanczos,
          scaling_mode: Zoom,
          sampling_method: Alphanumeric,
      )'';

    "${wallpaper}/custom-colors".text = ''
      [
          Single((0.0, 0.0, 0.0)),
      ]'';

    # ── Terminal — Source Code Pro 13 ────────────────────────────────────

    "${term}/font_name".text = ''"Source Code Pro"'';
    "${term}/font_size".text = "13";
    "${term}/use_bright_bold".text = "false";
    # Default: "${term}/opacity".text = "100";
    # Default: "${term}/show_headerbar".text = "true";
    # Default: "${term}/focus_follow_mouse".text = "false";

    # ── Idle — never sleep ──────────────────────────────────────────────

    "${idle}/screen_off_time".text = "None";
    "${idle}/suspend_on_ac_time".text = "None";

    # ── Shortcuts ───────────────────────────────────────────────────────

    # Default: system_actions = { Terminal: "cosmic-term" }

    # ── Screenshot — rectangle, save to Pictures ────────────────────────

    "${portal}/screenshot".text = ''
      (
          save_location: Pictures,
          choice: Rectangle,
      )'';

    # ── Files — details view ────────────────────────────────────────────

    "${files}/show_details".text = "true";

    # ── Clock applet ────────────────────────────────────────────────────

    # Default: "${c}/com.system76.CosmicAppletTime/v1/first_day_of_week".text = "0";
    # Default: "${c}/com.system76.CosmicAppletTime/v1/military_time".text = "false";
    # Default: "${c}/com.system76.CosmicAppletTime/v1/show_date_in_top_panel".text = "false";
    # Default: "${c}/com.system76.CosmicAppletTime/v1/show_seconds".text = "false";
  };
}
