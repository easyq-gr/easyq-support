# EasyQ Support: the only source change of this fork (see EASYQ.md). Run from the repository root after the checkout
# with submodules, before the build:
#   ./easyq/apply.ps1 -Variant customer   "EasyQ Support": what the customer runs; incoming only, "Accept" only
#   ./easyq/apply.ps1 -Variant tech       "EasyQ Support Tech": what EasyQ's own support staff run; outgoing only
# Every replacement must match exactly once; anything else stops the build, so a new RustDesk version that moved one of
# these lines fails loudly instead of building a client that talks to RustDesk's public servers.
param(
    [Parameter(Mandatory = $true)][ValidateSet('customer', 'tech')][string]$Variant
)
$ErrorActionPreference = 'Stop'
$file = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../libs/hbb_common/src/config.rs'))
$text = [IO.File]::ReadAllText($file)

function Swap([string]$old, [string]$new) {
    $n = ([regex]::Matches($script:text, [regex]::Escape($old))).Count
    if ($n -ne 1) { throw "EasyQ: expected this line once in $file, found it $n times: $old" }
    $script:text = $script:text.Replace($old, $new)
}
function RustMap([string[]]$pairs) {
    $items = @()
    for ($i = 0; $i -lt $pairs.Count; $i += 2) {
        $items += '("' + $pairs[$i] + '".to_owned(), "' + $pairs[$i + 1] + '".to_owned())'
    }
    'RwLock::new(HashMap::from([' + ($items -join ', ') + ']))'
}

if ($Variant -eq 'customer') {
    $appName = 'EasyQ Support'
    $connType = 'incoming'   # small window: logo, ID, status; can never connect out (client.rs bails "Incoming only mode")
} else {
    $appName = 'EasyQ Support Tech'
    $connType = 'outgoing'   # never registers an ID, never accepts a connection (rendezvous_mediator.rs start_all)
}

# Its own name, so its own settings folder (%APPDATA%\<name>): a RustDesk the user already has keeps its settings, and
# its settings (an account login, "stop service") never reach this client. Customer and tech differ too.
Swap 'pub static ref APP_NAME: RwLock<String> = RwLock::new("RustDesk".to_owned());' `
     ('pub static ref APP_NAME: RwLock<String> = RwLock::new("' + $appName + '".to_owned());')

# Our own ID / relay server and its PUBLIC key (id_ed25519.pub of the server; not a secret).
# PROD_RENDEZVOUS_SERVER is what RustDesk's own custom clients set: with it, using_public_server() is false, so the
# client does not show "please set up your own server" and does not cap the image quality as it does on the public
# servers. The API server stays off because of register-device = N below (get_api_server checks that first).
Swap 'pub const RENDEZVOUS_SERVERS: &[&str] = &["rs-ny.rustdesk.com"];' `
     'pub const RENDEZVOUS_SERVERS: &[&str] = &["remote.easyq.gr"];'
Swap 'pub static ref PROD_RENDEZVOUS_SERVER: RwLock<String> = RwLock::new("".to_owned());' `
     'pub static ref PROD_RENDEZVOUS_SERVER: RwLock<String> = RwLock::new("remote.easyq.gr".to_owned());'
Swap 'pub const RS_PUB_KEY: &str = "OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw=";' `
     'pub const RS_PUB_KEY: &str = "gaaueVLHGT0b5lgn8DyeB670xTNYPuajfLCrJTy+1mE=";'

# Settings the user cannot change:
#   approve-mode = click        a connection needs the user's "Accept", never a password
#   enable-check-update = N     no "a new version is out" prompt from RustDesk
#   enable-lan-discovery = N    nothing broadcast on the local network
Swap 'pub static ref OVERWRITE_SETTINGS: RwLock<HashMap<String, String>> = Default::default();' `
     ('pub static ref OVERWRITE_SETTINGS: RwLock<HashMap<String, String>> = ' +
      (RustMap @('approve-mode', 'click', 'enable-check-update', 'N', 'enable-lan-discovery', 'N')) + ';')

# No installation (no service, so no unattended access), no settings page, no account login, no address book, and the
# direction of the variant (conn-type).
Swap 'pub static ref HARD_SETTINGS: RwLock<HashMap<String, String>> = Default::default();' `
     ('pub static ref HARD_SETTINGS: RwLock<HashMap<String, String>> = ' +
      (RustMap @('disable-installation', 'Y', 'disable-settings', 'Y', 'disable-account', 'Y', 'disable-ab', 'Y',
                 'conn-type', $connType)) + ';')

# No API server at all: without it the client would call https://admin.rustdesk.com (common.rs get_api_server).
Swap 'pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = Default::default();' `
     ('pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = ' + (RustMap @('register-device', 'N')) + ';')

[IO.File]::WriteAllText($file, $text, (New-Object Text.UTF8Encoding($false)))
"EasyQ: config.rs changed for '$appName' (conn-type $connType; server, key, preset settings)"

# On every incoming connection the client starts its "connection manager" window (the "Accept" dialog, a second
# process) and waits for it only 20 x 0.3 s. A slow first start (antivirus on a new download, a slow PC) took 14 s in
# the test of 18/11 and every attempt failed with "Reset by the peer" until the window was already running. Wait up to
# 100 x 0.3 s = 30 s instead. Regex with \r?\n: the checkout may have CRLF or LF line ends.
$conn = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../src/server/connection.rs'))
$ctext = [IO.File]::ReadAllText($conn)
$cmWait = 'for _ in 0\.\.20 \{(\r?\n\s*)sleep\(0\.3\)\.await;(\r?\n\s*)if let Ok\(s\) = crate::ipc::connect\(1000, "_cm"\)\.await \{'
$n = ([regex]::Matches($ctext, $cmWait)).Count
if ($n -ne 1) { throw "EasyQ: expected the connection manager wait once in $conn, found it $n times" }
$ctext = [regex]::Replace($ctext, $cmWait, 'for _ in 0..100 {$1sleep(0.3).await;$2if let Ok(s) = crate::ipc::connect(1000, "_cm").await {')
[IO.File]::WriteAllText($conn, $ctext, (New-Object Text.UTF8Encoding($false)))
'EasyQ: src/server/connection.rs waits up to 30 s for the connection manager'

# EasyQ icons instead of RustDesk's. Every target must already exist (a moved file in a new RustDesk version stops the
# build), and icon.ico + icon.svg are required: a build never ships with RustDesk's icon by accident.
#   icon.ico       -> res/icon.ico (DLL resource), flutter/windows/runner/resources/app_icon.ico (exe, taskbar)
#   tray-icon.ico  -> res/tray-icon.ico (next to the clock); icon.ico when there is no separate tray icon
#   icon.svg       -> flutter/assets/icon.svg (small logo inside the window)
#   logo.png       -> flutter/assets/logo.png (optional; RustDesk shows it at the top, max 300x60)
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$brand = Join-Path $PSScriptRoot 'branding'
function Put([string]$from, [string]$to, [bool]$mustExist = $true) {
    $src = Join-Path $brand $from
    $dst = Join-Path $root $to
    if (-not (Test-Path $src)) { throw "EasyQ: missing easyq/branding/$from" }
    if ($mustExist -and -not (Test-Path $dst)) { throw "EasyQ: $to no longer exists in this RustDesk version" }
    Copy-Item -LiteralPath $src -Destination $dst -Force
    "EasyQ: $to <- branding/$from"
}
Put 'icon.ico' 'res/icon.ico'
Put 'icon.ico' 'flutter/windows/runner/resources/app_icon.ico'
if (Test-Path (Join-Path $brand 'tray-icon.ico')) { Put 'tray-icon.ico' 'res/tray-icon.ico' } else { Put 'icon.ico' 'res/tray-icon.ico' }
Put 'icon.svg' 'flutter/assets/icon.svg'
if (Test-Path (Join-Path $brand 'logo.png')) { Put 'logo.png' 'flutter/assets/logo.png' $false }
