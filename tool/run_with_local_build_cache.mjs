#!/usr/bin/env node
// Optional Mac-mini build-host profile. No credential copying, cache deletion,
// volume creation, mount operation or global environment/configuration change.
import assert from 'node:assert/strict';
import { execFileSync, spawn } from 'node:child_process';
import { lstatSync, readFileSync, realpathSync, statfsSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const minimumCacheFreeKiB = 5 * 1024 * 1024;
const root = fileURLToPath(new URL('..', import.meta.url));
const fail = (message) => { throw new Error(message); };
const inside = (parent, child) => {
  const relative = path.relative(parent, child);
  return relative !== '' && !relative.startsWith(`..${path.sep}`)
    && relative !== '..' && !path.isAbsolute(relative);
};

export function parseBuildCacheProfile(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail('invalid_build_cache_profile');
  const keys = ['version', 'cacheDirectory', 'mountPoint', 'imagePath', 'backingDirectory'];
  if (Object.keys(value).length !== keys.length || keys.some((key) => !Object.hasOwn(value, key)))
    fail('unexpected_build_cache_profile_fields');
  if (value.version !== 1) fail('unsupported_build_cache_profile_version');
  for (const key of keys.slice(1)) {
    if (typeof value[key] !== 'string' || !path.isAbsolute(value[key])
        || path.normalize(value[key]) !== value[key] || /[\r\n\0]/u.test(value[key]))
      fail('invalid_build_cache_path');
  }
  if (path.dirname(value.mountPoint) !== '/Volumes'
      || !path.basename(value.mountPoint).startsWith('SIT-Build-')) fail('unexpected_build_cache_mount');
  if (value.cacheDirectory !== path.join(value.mountPoint, 'gradle')) fail('unexpected_build_cache_directory');
  if (!inside('/Volumes', value.backingDirectory)
      || !inside(value.backingDirectory, value.imagePath)
      || !value.imagePath.endsWith('.sparsebundle')
      || inside(value.mountPoint, value.backingDirectory)) fail('invalid_build_cache_backing');
  return Object.freeze({ ...value });
}

export function validateBuildCacheObservation(profile, observation) {
  if (observation.platform !== 'darwin') fail('build_cache_requires_macos');
  if (!observation.directoriesAreReal || !observation.ownerOnly) fail('unsafe_build_cache_directory');
  if (observation.filesystemType !== 'apfs' || !observation.cacheOnMountedDevice)
    fail('build_cache_requires_exact_apfs_mount');
  if (observation.imagePath !== profile.imagePath || observation.mountPoint !== profile.mountPoint)
    fail('build_cache_image_mount_mismatch');
  if (!observation.backingOnSeparateDevice) fail('build_cache_backing_device_mismatch');
  for (const key of ['cacheFreeKiB', 'backingFreeKiB']) {
    if (!Number.isSafeInteger(observation[key]) || observation[key] < minimumCacheFreeKiB)
      fail('insufficient_build_cache_capacity');
  }
  return { cacheFreeKiB: observation.cacheFreeKiB, backingFreeKiB: observation.backingFreeKiB };
}

function plist(command, args) {
  try {
    const xml = execFileSync(command, args, { stdio: ['ignore', 'pipe', 'pipe'], timeout: 15_000 });
    return JSON.parse(execFileSync('/usr/bin/plutil', ['-convert', 'json', '-o', '-', '-'], {
      input: xml, stdio: ['pipe', 'pipe', 'pipe'], timeout: 15_000, encoding: 'utf8',
    }));
  } catch { fail('build_cache_disk_inventory_unavailable'); }
}

function freeKiB(directory) {
  const info = statfsSync(directory);
  return Math.floor(info.bavail * info.bsize / 1024);
}

export function observeBuildCache(profile) {
  if (process.platform !== 'darwin') fail('build_cache_requires_macos');
  const mount = lstatSync(profile.mountPoint);
  const cache = lstatSync(profile.cacheDirectory);
  const image = lstatSync(profile.imagePath);
  const backing = lstatSync(profile.backingDirectory);
  const real = [profile.mountPoint, profile.cacheDirectory, profile.imagePath, profile.backingDirectory]
    .every((entry) => realpathSync(entry) === entry);
  const disk = plist('/usr/sbin/diskutil', ['info', '-plist', profile.mountPoint]);
  const images = plist('/usr/bin/hdiutil', ['info', '-plist']);
  const matching = (images.images ?? []).find((entry) => entry['image-path'] === profile.imagePath
    && (entry['system-entities'] ?? []).some((entity) => entity['mount-point'] === profile.mountPoint));
  return {
    platform: process.platform,
    directoriesAreReal: real && [mount, cache, image, backing].every((entry) => entry.isDirectory() && !entry.isSymbolicLink()),
    ownerOnly: [mount, cache].every((entry) => entry.uid === process.getuid() && (entry.mode & 0o077) === 0),
    filesystemType: disk.FilesystemType,
    cacheOnMountedDevice: cache.dev === mount.dev && disk.MountPoint === profile.mountPoint,
    backingOnSeparateDevice: backing.dev !== mount.dev && statSync(profile.imagePath).dev === backing.dev,
    imagePath: matching?.['image-path'] ?? null,
    mountPoint: matching ? profile.mountPoint : null,
    cacheFreeKiB: freeKiB(profile.cacheDirectory),
    backingFreeKiB: freeKiB(profile.backingDirectory),
  };
}

export function parseBuildCacheArguments(args) {
  if (args[0] !== '--profile' || !args[1] || args[2] !== '--' || args.length < 4)
    fail('usage: --profile <owner-only-json> -- <command> [arguments]');
  return { profilePath: path.resolve(args[1]), command: args[3], args: args.slice(4) };
}

async function main(args) {
  const request = parseBuildCacheArguments(args);
  const info = lstatSync(request.profilePath);
  if (!info.isFile() || info.isSymbolicLink() || info.uid !== process.getuid() || (info.mode & 0o077) !== 0)
    fail('unsafe_build_cache_profile_file');
  const profile = parseBuildCacheProfile(JSON.parse(readFileSync(request.profilePath, 'utf8')));
  const before = validateBuildCacheObservation(profile, observeBuildCache(profile));
  process.stdout.write(`[SIT build cache] verified dedicated APFS cache; free KiB=${before.cacheFreeKiB}, backing KiB=${before.backingFreeKiB}\n`);
  const result = await new Promise((resolve, reject) => {
    const child = spawn(request.command, request.args, {
      cwd: root, env: { ...process.env, GRADLE_USER_HOME: profile.cacheDirectory }, stdio: 'inherit', shell: false,
    });
    const interrupt = () => child.kill('SIGINT');
    const terminate = () => child.kill('SIGTERM');
    process.once('SIGINT', interrupt);
    process.once('SIGTERM', terminate);
    const remove = () => { process.removeListener('SIGINT', interrupt); process.removeListener('SIGTERM', terminate); };
    child.once('error', (error) => { remove(); reject(error); });
    child.once('close', (code, signal) => { remove(); resolve({ code, signal }); });
  });
  // A disconnected/replaced disk or exhausted sparse backing is not success,
  // even when a child command returned zero. Never fall back to the global home.
  validateBuildCacheObservation(profile, observeBuildCache(profile));
  assert.ok(result.code === null || Number.isInteger(result.code));
  process.exitCode = result.signal || result.code === null ? 1 : result.code;
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main(process.argv.slice(2)).catch(() => {
    // Do not relay disk inventory, profile contents or arbitrary child errors.
    process.stderr.write('SIT build-cache guard failed; no fallback to the global cache.\n');
    process.exitCode = 1;
  });
}
