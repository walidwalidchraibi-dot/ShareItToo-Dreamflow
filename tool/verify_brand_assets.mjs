#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));

function fail(message) {
  console.error(`ERROR: ${message}`);
  process.exit(1);
}

function asset(path, width, height = width) {
  return { path, width, height };
}

const expectedHashBySize = new Map([
  ['20x20', '8b20c00f2966e1a4a321833134256401bc3f43528e899259197a1c832fb84a5d'],
  ['29x29', 'e200d41326425a723af97bd07264a5b0a990e7d7469d9f2dcfce1f2bb98ccec0'],
  ['32x32', '2e4a36d390240983cfc8515397294d87cae62a296bd0176be3c5688785da7713'],
  ['40x40', '0c4efa6d414357bbbb9495849475faee7f26aa04a3ae05df238e561b8de63a9c'],
  ['48x48', 'f3f49413a0362a9526232e7c3203fb82946d731e96d507a40a6fe8b9c55a2f1d'],
  ['58x58', 'e348beea64fe17bcaf84d56dd8f979541f3ec9053368ba8be42693c10a3a588f'],
  ['60x60', '97103811c775bbddfe41b1814b9c73b54db4f27a5ac895aced917197280cff33'],
  ['72x72', 'fd63e0b7561b307c35c67f94699ed8eb8d00e0c926f93e6dfec4d6d95bc6bca3'],
  ['76x76', 'adcac301d269363ac30a2c55086f3a4271cd02e5f20a165137215393014f1b00'],
  ['80x80', 'a61cf2e99616ded671b27b45fb54b4ffd09eadfe8540c28b5ba57cb5bc875bb2'],
  ['87x87', '2ab59e76abb5ef18d385ceaf826333340f5b6781cd2ec25b8dec0ddc2f8e2e33'],
  ['96x96', '92e4a8cceb7e71ed6134cf7aab6604ffc0bc2c9d3d7352dc12ead985b9d3da87'],
  ['120x120', 'cca0372e1c6d68b5ae3b5e03b6415cfa83a9bb885d84239738e4e6e50a011769'],
  ['144x144', '9e3a7a0f0f0a606df85252fe5a94809477345f63ced1c205804269b679cd6d56'],
  ['152x152', 'd479afa4acda3e651b263246ed75b21c5407c970b8d137e75081d16b2e8faacf'],
  ['167x167', 'f4cf047a8398a89bc8cb607e597754110ebbedcbc2937580a6b12e521e07f41b'],
  ['168x168', '9c7b2a23d310a14f6cf9eb457290fccc5294c0832f2929c45c03504e940fd042'],
  ['180x180', '501a26377714b2852f8c7e837a13c76f5dc6e31e7f683c172bf0ac94ab6faf27'],
  ['192x192', 'c99ee3ca99972ce20c711009d5b441ae778b0a680d978b4fcdf442ad3dc8b1fe'],
  ['288x288', 'b80a34b8e6b34431b095d12c36c3e984d701395f5edfd86df74b8f7ddb684d57'],
  ['336x336', '9f1745d965831fb3d9a4dbce08a3a7fa1c320d4cd8228ce0d1511e7671355214'],
  ['384x384', '528127b5b666a96cf87c386e68c9232763acd2db60298314729365a89bf6afb2'],
  ['504x504', '9b8ac6105879d3ceabce0a0405e3519901d4830682d8eea64cd6a5a79952adca'],
  ['512x512', '117e4547b5de671031213d579b91b5f110ad9042ad731353ea9de6d34cc99f01'],
  ['1024x1024', '7168ea38b286aa0d9e74a54f922ce4ea0ee1f4ce819e0a3d255e360ddcc459ec'],
]);

const assets = [
  asset('assets/images/shareittoo_app_icon_master.png', 1024),
  asset('web/favicon.png', 32),
  asset('web/icons/Icon-192.png', 192),
  asset('web/icons/Icon-512.png', 512),
  asset('web/icons/Icon-maskable-192.png', 192),
  asset('web/icons/Icon-maskable-512.png', 512),
  asset('android/app/src/main/res/mipmap-mdpi/ic_launcher.png', 48),
  asset('android/app/src/main/res/mipmap-hdpi/ic_launcher.png', 72),
  asset('android/app/src/main/res/mipmap-xhdpi/ic_launcher.png', 96),
  asset('android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png', 144),
  asset('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png', 192),
  asset('android/app/src/main/res/mipmap-mdpi/launch_logo.png', 96),
  asset('android/app/src/main/res/mipmap-hdpi/launch_logo.png', 144),
  asset('android/app/src/main/res/mipmap-xhdpi/launch_logo.png', 192),
  asset('android/app/src/main/res/mipmap-xxhdpi/launch_logo.png', 288),
  asset('android/app/src/main/res/mipmap-xxxhdpi/launch_logo.png', 384),
  asset('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png', 20),
  asset('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png', 40),
  asset('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png', 60),
  asset('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png', 29),
  asset('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png', 58),
  asset('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png', 87),
  asset('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png', 40),
  asset('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png', 80),
  asset('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png', 120),
  asset('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png', 120),
  asset('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png', 180),
  asset('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png', 76),
  asset('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png', 152),
  asset('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png', 167),
  asset('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png', 1024),
  asset('ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png', 168),
  asset('ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png', 336),
  asset('ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png', 504),
];

const notificationAssets = [
  { ...asset('android/app/src/main/res/drawable-mdpi/ic_stat_shareittoo.png', 24), sha256: 'ede5b004be2b6c30308588d4fb9432adbc5b594e64d5359a48f8c033a54c06de' },
  { ...asset('android/app/src/main/res/drawable-hdpi/ic_stat_shareittoo.png', 36), sha256: 'dd93abe41635320feef5622107b26e38e336990e1e913ad16ac6d29a20e1f05f' },
  { ...asset('android/app/src/main/res/drawable-xhdpi/ic_stat_shareittoo.png', 48), sha256: 'efd766415889587fd8c3b5793a8d26957bba48d578ab5784a08d03ca7cd4cbce' },
  { ...asset('android/app/src/main/res/drawable-xxhdpi/ic_stat_shareittoo.png', 72), sha256: '9a21e40f1d8d709834a85c81c9e02397b105233752b2f0b83ed15683a3e341a3' },
  { ...asset('android/app/src/main/res/drawable-xxxhdpi/ic_stat_shareittoo.png', 96), sha256: 'ae0879587da8edfcf130c43586b13578c2b3bc934b769a37fdb52b2e9c42f5b1' },
];

function inspectPng(relativePath) {
  const contents = readFileSync(`${root}${relativePath}`);
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (!contents.subarray(0, 8).equals(signature)) {
    fail(`${relativePath} is not a PNG file.`);
  }

  if (contents.toString('ascii', 12, 16) !== 'IHDR') {
    fail(`${relativePath} has no leading IHDR chunk.`);
  }

  return {
    width: contents.readUInt32BE(16),
    height: contents.readUInt32BE(20),
    bitDepth: contents[24],
    colorType: contents[25],
    interlace: contents[28],
    sha256: createHash('sha256').update(contents).digest('hex'),
  };
}

for (const entry of assets) {
  const png = inspectPng(entry.path);
  const key = `${entry.width}x${entry.height}`;
  const expectedHash = expectedHashBySize.get(key);

  if (png.width !== entry.width || png.height !== entry.height) {
    fail(`${entry.path} must be ${key}, found ${png.width}x${png.height}.`);
  }
  if (png.bitDepth !== 8 || png.colorType !== 2 || png.interlace !== 0) {
    fail(`${entry.path} must be an opaque, non-interlaced 8-bit RGB PNG.`);
  }
  if (!expectedHash || png.sha256 !== expectedHash) {
    fail(`${entry.path} is not the approved white ShareItToo master rendering for ${key}.`);
  }
}

for (const entry of notificationAssets) {
  const png = inspectPng(entry.path);
  if (png.width !== entry.width || png.height !== entry.height) {
    fail(`${entry.path} must be ${entry.width}x${entry.height}.`);
  }
  if (png.bitDepth !== 8 || png.colorType !== 6 || png.interlace !== 0) {
    fail(`${entry.path} must be a transparent, non-interlaced 8-bit RGBA PNG.`);
  }
  if (png.sha256 !== entry.sha256) {
    fail(`${entry.path} is not the approved ShareItToo notification silhouette.`);
  }
}

const manifest = JSON.parse(readFileSync(`${root}web/manifest.json`, 'utf8'));
if (manifest.background_color !== '#FFFFFF') {
  fail('web/manifest.json must use a white PWA background_color.');
}
if (manifest.theme_color !== '#0EA5E9') {
  fail('web/manifest.json must use the ShareItToo primary theme color.');
}

const expectedWebIcons = new Map([
  ['icons/Icon-192.png', '192x192:any'],
  ['icons/Icon-512.png', '512x512:any'],
  ['icons/Icon-maskable-192.png', '192x192:maskable'],
  ['icons/Icon-maskable-512.png', '512x512:maskable'],
]);
for (const icon of manifest.icons ?? []) {
  const key = `${icon.sizes}:${icon.purpose ?? 'any'}`;
  if (icon.type !== 'image/png' || expectedWebIcons.get(icon.src) !== key) {
    fail(`Unexpected PWA icon declaration for ${icon.src ?? '<missing src>'}.`);
  }
  expectedWebIcons.delete(icon.src);
}
if (expectedWebIcons.size !== 0) {
  fail(`Missing PWA icon declarations: ${[...expectedWebIcons.keys()].join(', ')}.`);
}

const androidColors = readFileSync(
  `${root}android/app/src/main/res/values/colors.xml`,
  'utf8',
);
if (!androidColors.includes('<color name="shareittoo_launch_background">#FFFFFF</color>')) {
  fail('Android launch background must remain white.');
}
if (!androidColors.includes('<color name="shareittoo_notification_accent">#00A9E0</color>')) {
  fail('Android notification accent must use the ShareItToo blue.');
}

const androidManifest = readFileSync(
  `${root}android/app/src/main/AndroidManifest.xml`,
  'utf8',
);
if (!androidManifest.includes('com.google.firebase.messaging.default_notification_icon')
    || !androidManifest.includes('android:resource="@drawable/ic_stat_shareittoo"')) {
  fail('Android Firebase notifications must use the approved ShareItToo status icon.');
}
if (!androidManifest.includes('com.google.firebase.messaging.default_notification_color')
    || !androidManifest.includes('android:resource="@color/shareittoo_notification_accent"')) {
  fail('Android Firebase notifications must use the ShareItToo accent color.');
}

const iosLaunchScreen = readFileSync(
  `${root}ios/Runner/Base.lproj/LaunchScreen.storyboard`,
  'utf8',
);
if (!iosLaunchScreen.includes('<color key="backgroundColor" white="1" alpha="1"')) {
  fail('iOS launch background must remain opaque white.');
}

console.log(`Brand asset verification passed for ${assets.length} PNG files.`);
