use super::win_topmost_window::{LEGACY_PRIVACY_WINDOW_NAME, PRIVACY_WINDOW_NAME};
use hbb_common::{bail, log, ResultType};
use std::time::Instant;

pub use super::win_topmost_window::PrivacyModeImpl;

pub(super) const PRIVACY_MODE_IMPL: &str = super::PRIVACY_MODE_IMPL_WIN_MAG;

pub fn create_capturer(
    privacy_mode_id: i32,
    origin: (i32, i32),
    width: usize,
    height: usize,
) -> ResultType<Option<scrap::CapturerMag>> {
    if !super::is_current_privacy_mode_impl(PRIVACY_MODE_IMPL) {
        return Ok(None);
    }

    match scrap::CapturerMag::new(origin, width, height) {
        Ok(mut c1) => {
            let mut ok = false;
            let check_begin = Instant::now();
            while check_begin.elapsed().as_secs() < 5 {
                let primary_res = c1.exclude("", PRIVACY_WINDOW_NAME);
                let legacy_res = c1.exclude("", LEGACY_PRIVACY_WINDOW_NAME);
                match (primary_res, legacy_res) {
                    (Ok(true), _) | (_, Ok(true)) => {
                        ok = true;
                        break;
                    }
                    (Err(e), _) => {
                        bail!(
                            "Failed to exclude privacy window {} - {}, err: {}",
                            "",
                            PRIVACY_WINDOW_NAME,
                            e
                        );
                    }
                    (_, Err(e)) => {
                        bail!(
                            "Failed to exclude privacy window {} - {}, err: {}",
                            "",
                            LEGACY_PRIVACY_WINDOW_NAME,
                            e
                        );
                    }
                    _ => {
                        ok = false;
                        std::thread::sleep(std::time::Duration::from_millis(500));
                    }
                }
            }
            if !ok {
                bail!(
                    "Failed to exclude privacy window {} - {} ",
                    "",
                    PRIVACY_WINDOW_NAME
                );
            }
            log::debug!("Create magnifier capture for {}", privacy_mode_id);
            Ok(Some(c1))
        }
        Err(e) => {
            bail!(format!("Failed to create magnifier capture {}", e));
        }
    }
}
