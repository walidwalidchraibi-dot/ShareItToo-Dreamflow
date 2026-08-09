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
  ['20x20', '60cdda719b951ada5ea63b08f4e6bfb98513de9dc2670e0db2b7d7a32d449c37'],
  ['29x29', 'da5353f28e751d90dd88b6439c4e7a4cad7b8ece2df8b240ca47ec22f314e536'],
  ['32x32', '54b604fb1a54ffd00075d06d9d152551a8a8fedcc60d7ccbdb3ba4b92c1b0747'],
  ['40x40', '68a1354ce0d7adb704987c3996efb84343aa7a39a58d755000db22fdb341e375'],
  ['48x48', '656a599014a743374d69767a424c78b2e152a0e0dabf71219002f9d08f38c63e'],
  ['58x58', '4a66e54290a6c92fd5057d35267458b15585ff4f328eaa6b26721d881f98b77c'],
  ['60x60', '4884a084291806c841a077a3155ba919ce141a5a06ea24e939a05eefdfbf32b9'],
  ['72x72', '67b679e28ea80426c9556ea271d51037e3b17b820aa2d3f1643d00a735df1771'],
  ['76x76', '541233ff0d968384044381734349ba75f97b8d05d6d7ddd6c007a89177fe0505'],
  ['80x80', 'fafab33345343cb28e2f2d80b94667564b90c6a97138cab2a027b8cd56f004a0'],
  ['87x87', '7b6bcc1d48f12e60555ef21e69b902e3e20171158951094a5638c73ae1883c6c'],
  ['96x96', '889819cd84874164a21608306687fd0dc16551f36c6006dfd239aed98793cb6a'],
  ['120x120', 'f1843406c715865f83674b5cb47afd8d6845f364f41c8d7f102733e236086c4c'],
  ['144x144', 'bf8d2f3e06fa14972d52f31033c7800bae7befb1ee5e354c32550ec8ddbcced7'],
  ['152x152', 'af5fd5b626ce95051004086ee1c8a6a37ebcdf4e51c1ae56aebcfa859dd4aaea'],
  ['167x167', '1a604b44c9d3940a39578aca4deacf2fe57d1b2009519f7337e7fe6bd40f6d40'],
  ['168x168', 'bb3837fa8b01fca2ed5dbc0765705c91be6718e74c3b86e5c7fdcdb074523e4a'],
  ['180x180', '47d1647ed1d332e8abb985e6eadb49837443ce7b3fff1ff9e501c86218e0497b'],
  ['192x192', '508c0fc9c3b802f038a073e00696d304b6c0c53b32251c6da7f11ea8309307bd'],
  ['288x288', 'dbc90e81e76be4132f98d43fa150df6b026d5ae93a268d1de8d7007514bdfac4'],
  ['336x336', '859c95c7ab9e9e14714bc17f861e9d9b036ec61b97882b900e4a5e6710f7ecdc'],
  ['384x384', 'c4b1ff3e09088abcf3db07c452f0e025f759513338bc8e3a15ee693e284a0637'],
  ['504x504', 'de576fdd6d35a0d05a2147cfb0cf9888e50d6c49876e1e5dad99aefb95075b56'],
  ['512x512', '2458f861708e87c935346ed8f4d48e144d0cc2738d996810dca5f3520944caff'],
  ['1024x1024', '8c0177d8e8d6c57013f01a53b266c8b758e0fc60f3201b4e3b6c198dd9455a08'],
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

const iosLaunchScreen = readFileSync(
  `${root}ios/Runner/Base.lproj/LaunchScreen.storyboard`,
  'utf8',
);
if (!iosLaunchScreen.includes('<color key="backgroundColor" white="1" alpha="1"')) {
  fail('iOS launch background must remain opaque white.');
}

console.log(`Brand asset verification passed for ${assets.length} PNG files.`);
