mod cosmic_toplevel {
    pub use self::generated::client;

    mod generated {
        #![allow(dead_code, non_camel_case_types, unused_unsafe, unused_variables)]
        #![allow(non_upper_case_globals, non_snake_case, unused_imports)]
        #![allow(missing_docs, clippy::all)]

        pub mod client {
            use wayland_client;
            use wayland_client::protocol::*;

            pub mod __interfaces {
                use wayland_client::backend as wayland_backend;
                use wayland_client::protocol::__interfaces::*;
                wayland_scanner::generate_interfaces!("protocols/cosmic-toplevel-info-unstable-v1.xml");
            }
            use self::__interfaces::*;

            wayland_scanner::generate_client_code!("protocols/cosmic-toplevel-info-unstable-v1.xml");
        }
    }
}

use cosmic_toplevel::client::zcosmic_toplevel_handle_v1;
use cosmic_toplevel::client::zcosmic_toplevel_info_v1;
use serde_json::json;
use std::collections::HashMap;
use std::time::{Duration, Instant, SystemTime};
use wayland_client::Proxy;
use wayland_client::event_created_child;
use wayland_client::protocol::{wl_output, wl_registry};
use wayland_client::{Connection, Dispatch, QueueHandle, globals::GlobalListContents};

const PULSETIME: u64 = 2;
const POLL_INTERVAL: Duration = Duration::from_secs(1);

#[derive(Debug, Default)]
struct ToplevelInfo {
    title: String,
    app_id: String,
    activated: bool,
    pending_title: Option<String>,
    pending_app_id: Option<String>,
    pending_activated: Option<bool>,
}

struct State {
    toplevels: HashMap<wayland_client::backend::ObjectId, ToplevelInfo>,
    hostname: String,
    port: u16,
    bucket_created: bool,
    last_heartbeat: Instant,
}

impl State {
    fn new(hostname: String, port: u16) -> Self {
        Self {
            toplevels: HashMap::new(),
            hostname,
            port,
            bucket_created: false,
            last_heartbeat: Instant::now() - POLL_INTERVAL,
        }
    }

    fn base_url(&self) -> String {
        format!("http://127.0.0.1:{}/api/0", self.port)
    }

    fn bucket_id(&self) -> String {
        format!("aw-watcher-window_{}", self.hostname)
    }

    fn ensure_bucket(&mut self) {
        if self.bucket_created {
            return;
        }
        let url = format!("{}/buckets/{}", self.base_url(), self.bucket_id());
        let body = json!({
            "client": "aw-watcher-window-cosmic",
            "type": "currentwindow",
            "hostname": self.hostname,
        });
        match ureq::post(&url).send_json(body) {
            Ok(_) => {
                self.bucket_created = true;
                eprintln!("[aw-watcher-window-cosmic] Created bucket {}", self.bucket_id());
            }
            Err(e) => eprintln!("[aw-watcher-window-cosmic] Failed to create bucket: {e}"),
        }
    }

    fn send_heartbeat(&mut self) {
        if self.last_heartbeat.elapsed() < POLL_INTERVAL {
            return;
        }

        self.ensure_bucket();
        if !self.bucket_created {
            return;
        }

        let (title, app) = self.active_window();
        let url = format!(
            "{}/buckets/{}/heartbeat?pulsetime={}",
            self.base_url(),
            self.bucket_id(),
            PULSETIME,
        );
        let body = json!({
            "timestamp": iso8601_now(),
            "duration": 0,
            "data": {
                "app": app,
                "title": title,
            },
        });
        match ureq::post(&url).send_json(body) {
            Ok(_) => {}
            Err(e) => eprintln!("[aw-watcher-window-cosmic] Heartbeat failed: {e}"),
        }
        self.last_heartbeat = Instant::now();
    }

    fn active_window(&self) -> (String, String) {
        for info in self.toplevels.values() {
            if info.activated {
                return (info.title.clone(), info.app_id.clone());
            }
        }
        ("unknown".into(), "unknown".into())
    }
}

fn iso8601_now() -> String {
    let d = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap();
    let secs = d.as_secs();
    let micros = d.subsec_micros();
    let days = secs / 86400;
    let day_secs = secs % 86400;
    let h = day_secs / 3600;
    let m = (day_secs % 3600) / 60;
    let s = day_secs % 60;
    let (year, month, day) = days_to_ymd(days);
    format!("{year:04}-{month:02}-{day:02}T{h:02}:{m:02}:{s:02}.{micros:06}+00:00")
}

fn days_to_ymd(days: u64) -> (u64, u64, u64) {
    let z = days + 719468;
    let era = z / 146097;
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    (y, m, d)
}

// TODO: Add ext-foreign-toplevel-list-v1 support to work on all Wayland compositors
// (Sway, Hyprland, GNOME, etc.), not just COSMIC. Try ext-foreign-toplevel-list first,
// fall back to zcosmic_toplevel_info_v1. Then rename to aw-watcher-window-linux.

// --- Wayland dispatch ---

impl Dispatch<wl_registry::WlRegistry, GlobalListContents> for State {
    fn event(
        _: &mut Self, _: &wl_registry::WlRegistry, _: wl_registry::Event,
        _: &GlobalListContents, _: &Connection, _: &QueueHandle<Self>,
    ) {}
}

impl Dispatch<wl_output::WlOutput, ()> for State {
    fn event(
        _: &mut Self, _: &wl_output::WlOutput, _: wl_output::Event,
        _: &(), _: &Connection, _: &QueueHandle<Self>,
    ) {}
}

impl Dispatch<zcosmic_toplevel_info_v1::ZcosmicToplevelInfoV1, ()> for State {
    fn event(
        _: &mut Self,
        _: &zcosmic_toplevel_info_v1::ZcosmicToplevelInfoV1,
        event: zcosmic_toplevel_info_v1::Event,
        _: &(), _: &Connection, _: &QueueHandle<Self>,
    ) {
        if let zcosmic_toplevel_info_v1::Event::Finished = event {
            eprintln!("[aw-watcher-window-cosmic] Compositor finished toplevel info");
            std::process::exit(0);
        }
    }

    event_created_child!(State, zcosmic_toplevel_info_v1::ZcosmicToplevelInfoV1, [
        zcosmic_toplevel_info_v1::EVT_TOPLEVEL_OPCODE => (zcosmic_toplevel_handle_v1::ZcosmicToplevelHandleV1, ()),
    ]);
}

impl Dispatch<zcosmic_toplevel_handle_v1::ZcosmicToplevelHandleV1, ()> for State {
    fn event(
        state: &mut Self,
        proxy: &zcosmic_toplevel_handle_v1::ZcosmicToplevelHandleV1,
        event: zcosmic_toplevel_handle_v1::Event,
        _: &(), _: &Connection, _: &QueueHandle<Self>,
    ) {
        let id = proxy.id();
        match event {
            zcosmic_toplevel_handle_v1::Event::Title { title } => {
                let info = state.toplevels.entry(id).or_default();
                info.pending_title = Some(title);
            }
            zcosmic_toplevel_handle_v1::Event::AppId { app_id } => {
                let info = state.toplevels.entry(id).or_default();
                info.pending_app_id = Some(app_id);
            }
            zcosmic_toplevel_handle_v1::Event::State { state: raw } => {
                let activated = raw
                    .chunks_exact(4)
                    .any(|c| u32::from_ne_bytes([c[0], c[1], c[2], c[3]]) == 2);
                let info = state.toplevels.entry(id).or_default();
                info.pending_activated = Some(activated);
            }
            zcosmic_toplevel_handle_v1::Event::Done => {
                let info = state.toplevels.entry(id).or_default();
                if let Some(t) = info.pending_title.take() { info.title = t; }
                if let Some(a) = info.pending_app_id.take() { info.app_id = a; }
                if let Some(a) = info.pending_activated.take() { info.activated = a; }
                state.send_heartbeat();
            }
            zcosmic_toplevel_handle_v1::Event::Closed => {
                state.toplevels.remove(&id);
                proxy.destroy();
                state.send_heartbeat();
            }
            _ => {}
        }
    }
}

fn main() {
    let hostname = std::fs::read_to_string("/etc/hostname")
        .unwrap_or_else(|_| "unknown".into())
        .trim()
        .to_string();
    let port: u16 = std::env::var("AW_PORT")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(5600);

    eprintln!("[aw-watcher-window-cosmic] Starting for host={hostname} port={port}");

    let conn = Connection::connect_to_env().expect("Failed to connect to Wayland display");
    let (globals, mut event_queue) =
        wayland_client::globals::registry_queue_init::<State>(&conn)
            .expect("Failed to initialize registry");

    let mut state = State::new(hostname, port);
    let qh = event_queue.handle();

    let _toplevel_info: zcosmic_toplevel_info_v1::ZcosmicToplevelInfoV1 = globals
        .bind(&qh, 1..=1, ())
        .expect("Compositor does not support zcosmic_toplevel_info_v1 — is this COSMIC?");

    eprintln!("[aw-watcher-window-cosmic] Bound zcosmic_toplevel_info_v1, entering event loop");

    loop {
        event_queue
            .blocking_dispatch(&mut state)
            .expect("Wayland dispatch failed");
    }
}
