// Builds .github/workflows/easyq-build.yml from RustDesk's own flutter-build.yml of the same version: its env block
// (without the signing secrets) and its Windows x86_64 job, run twice (variant customer and tech, see apply.ps1), plus
// the step that applies easyq/apply.ps1. On a new RustDesk version: take its flutter-build.yml and run this again.
// Usage (from anywhere): node easyq/make-workflow.js
const fs = require('fs');
const path = require('path');
const repo = path.join(__dirname, '..');
const src = fs.readFileSync(path.join(repo, '.github/workflows/flutter-build.yml'), 'utf8').replace(/\r\n/g, '\n');
const lines = src.split('\n');

const envStart = lines.findIndex(l => /^env:\s*$/.test(l));
const jobsStart = lines.findIndex(l => /^jobs:\s*$/.test(l));
if (envStart < 0 || jobsStart < 0) throw new Error('env / jobs not found');
const env = lines.slice(envStart + 1, jobsStart).filter(l =>
  !/secrets\./.test(l) && !/UPLOAD_ARTIFACT|PUBLISH_UPDATE_METADATA|TAG_NAME/.test(l) && !/^\s*#signing keys/.test(l));

const jobStart = lines.findIndex(l => /^  build-for-windows-flutter:\s*$/.test(l));
const jobEnd = lines.findIndex((l, i) => i > jobStart && /^  [A-Za-z0-9_-]+:\s*$/.test(l));
let job = lines.slice(jobStart, jobEnd);

// cut everything from the signing step on: the files are signed afterwards with the EasyQ certificate
const signAt = job.findIndex(l => /^      - name: Sign rustdesk files/.test(l));
if (signAt < 0) throw new Error('sign step not found');
job = job.slice(0, signAt);

let text = job.join('\n');
function swap(re, to, what) { if (!re.test(text)) throw new Error('not found: ' + what); text = text.replace(re, to); }
swap(/^  build-for-windows-flutter:$/m, '  build-easyq-support-windows:', 'job name');
swap(/^    name: \$\{\{ matrix\.job\.target \}\}$/m, '    name: ${{ matrix.job.target }} (${{ matrix.variant }})', 'job title');
// x86_64 only: drop the arm64 entry of the matrix
swap(/\n          - \{\n              target: aarch64-pc-windows-msvc,[\s\S]*?\n            \}\n/, '\n', 'arm64 matrix entry');
// both variants of apply.ps1, as a second matrix key (each job entry x each variant)
swap(/(\n            \}\n)(    steps:\n)/, '$1        variant: [customer, tech]\n$2', 'matrix end');
// the change itself, right after the checkout
swap(/(      - name: Checkout source code\n        uses: actions\/checkout@[^\n]+\n        with:\n          submodules: recursive\n)/,
  '$1\n      - name: Apply the EasyQ Support changes (easyq/apply.ps1)\n        shell: pwsh\n        run: ./easyq/apply.ps1 -Variant ${{ matrix.variant }}\n', 'checkout step');
// no Rust tests here (the workflow has no inputs; tests are RustDesk's own job)
swap(/\n      - name: Run the Rust tests\n[\s\S]*?(?=\n      - name: )/, '', 'rust tests step');
// the top-most window files are always needed (the original reads inputs.upload-artifact, which this workflow has not)
swap(/(      - name: Download RustDeskTempTopMostWindow artifacts\n        uses: [^\n]+\n)        if: \$\{\{ inputs\.upload-artifact \}\}\n/, '$1', 'topmost if');
// our own artifact name, one per variant
swap(/name: rustdesk-unsigned-windows-\$\{\{ matrix\.job\.arch \}\}/,
  'name: easyq-support-${{ matrix.variant }}-unsigned-windows-${{ matrix.job.arch }}', 'artifact name');
if (/inputs\./.test(text)) throw new Error('an inputs. reference is left: ' + text.match(/.*inputs\..*/)[0]);

const out = [
  '# EasyQ Support (EASYQ.md): RustDesk for Windows x64 with the changes of easyq/apply.ps1, unsigned, in two variants:',
  '# customer ("EasyQ Support") and tech ("EasyQ Support Tech").',
  '# Made by easyq/make-workflow.js from RustDesk\'s flutter-build.yml of the same version: on a new RustDesk version,',
  '# take the new flutter-build.yml and make this file again, never edit it by hand.',
  'name: EasyQ Support build (Windows x64)',
  '',
  'on:',
  '  workflow_dispatch:',
  '',
  'env:',
  ...env,
  '  UPLOAD_ARTIFACT: "true"',
  '',
  'jobs:',
  '  generate-bridge:',
  '    uses: ./.github/workflows/bridge.yml',
  '',
  '  build-RustDeskTempTopMostWindow:',
  '    uses: ./.github/workflows/third-party-RustDeskTempTopMostWindow.yml',
  '    with:',
  '      upload-artifact: true',
  '      target: windows-2022',
  '      configuration: Release',
  '      platform: x64',
  '      target_version: Windows10',
  '',
  text.replace(/\s+$/, ''),
  '',
].join('\n');
fs.writeFileSync(path.join(repo, '.github/workflows/easyq-build.yml'), out, 'utf8');
console.log('easyq-build.yml: ' + out.split('\n').length + ' lines');
