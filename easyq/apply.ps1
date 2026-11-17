# EasyQ Support: the only source change of this fork (see EASYQ.md). Run from the repository root after the checkout
# with submodules, before the build. Every replacement must match exactly once; anything else stops the build, so a new
# RustDesk version that moved one of these lines fails loudly instead of building a client that talks to RustDesk's
# public servers.
$ErrorActionPreference = 'Stop'
$file = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../libs/hbb_common/src/config.rs'))
$text = [IO.File]::ReadAllText($file)

function Swap([string]$old, [string]$new) {
    $n = ([regex]::Matches($script:text, [regex]::Escape($old))).Count
    if ($n -ne 1) { throw "EasyQ: expected this line once in $file, found it $n times: $old" }
    $script:text = $script:text.Replace($old, $new)
}

# Its own name, so its own settings folder (%APPDATA%\EasyQ Support): a RustDesk the user already has keeps its settings,
# and its settings (an account login, "stop service") never reach this client.
Swap 'pub static ref APP_NAME: RwLock<String> = RwLock::new("RustDesk".to_owned());' `
     'pub static ref APP_NAME: RwLock<String> = RwLock::new("EasyQ Support".to_owned());'

# Our own ID / relay server and its PUBLIC key (id_ed25519.pub of the server; not a secret).
Swap 'pub const RENDEZVOUS_SERVERS: &[&str] = &["rs-ny.rustdesk.com"];' `
     'pub const RENDEZVOUS_SERVERS: &[&str] = &["remote.easyq.gr"];'
Swap 'pub const RS_PUB_KEY: &str = "OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw=";' `
     'pub const RS_PUB_KEY: &str = "gaaueVLHGT0b5lgn8DyeB670xTNYPuajfLCrJTy+1mE=";'

# Settings the user cannot change:
#   approve-mode = click        a connection needs the user's "Accept", never a password
#   enable-check-update = N     no "a new version is out" prompt from RustDesk
#   enable-lan-discovery = N    nothing broadcast on the local network
Swap 'pub static ref OVERWRITE_SETTINGS: RwLock<HashMap<String, String>> = Default::default();' `
     'pub static ref OVERWRITE_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from([("approve-mode".to_owned(), "click".to_owned()), ("enable-check-update".to_owned(), "N".to_owned()), ("enable-lan-discovery".to_owned(), "N".to_owned())]));'

# No installation (no service, so no unattended access), no settings page, no account login, no address book.
Swap 'pub static ref HARD_SETTINGS: RwLock<HashMap<String, String>> = Default::default();' `
     'pub static ref HARD_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from([("disable-installation".to_owned(), "Y".to_owned()), ("disable-settings".to_owned(), "Y".to_owned()), ("disable-account".to_owned(), "Y".to_owned()), ("disable-ab".to_owned(), "Y".to_owned())]));'

# No API server at all: without it the client would call https://admin.rustdesk.com (common.rs get_api_server).
Swap 'pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = Default::default();' `
     'pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from([("register-device".to_owned(), "N".to_owned())]));'

[IO.File]::WriteAllText($file, $text, (New-Object Text.UTF8Encoding($false)))
'EasyQ: config.rs changed (name, server, key, preset settings)'
