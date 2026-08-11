import 'dart:convert';
import 'dart:io';

Never _fail(String message) {
  stderr.writeln('ERROR: $message');
  exit(1);
}

String _readText(Directory root, String relativePath) {
  final file = File('${root.path}/$relativePath');
  if (!file.existsSync()) {
    _fail('Missing store metadata file: $relativePath');
  }
  final value = file.readAsStringSync().trim();
  if (value.isEmpty) {
    _fail('Store metadata file is empty: $relativePath');
  }
  return value;
}

List<dynamic> _readJsonList(Directory root, String relativePath) {
  final file = File('${root.path}/$relativePath');
  if (!file.existsSync()) {
    _fail('Missing store metadata file: $relativePath');
  }
  Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException {
    _fail('Store metadata file is not valid JSON: $relativePath');
  }
  if (decoded is! List) {
    _fail('Store metadata file must contain a JSON list: $relativePath');
  }
  return decoded;
}

void _validateGooglePlayIcon(Directory root, String relativePath) {
  final file = File('${root.path}/$relativePath');
  if (!file.existsSync()) {
    _fail('Missing Google Play store icon: $relativePath');
  }
  final bytes = file.readAsBytesSync();
  if (bytes.length > 1024 * 1024) {
    _fail('Google Play store icon exceeds 1,024 KB.');
  }
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 33 ||
      !List<int>.generate(8, (index) => bytes[index])
          .asMap()
          .entries
          .every((entry) => entry.value == signature[entry.key])) {
    _fail('Google Play store icon must be a valid PNG.');
  }
  final chunkType = ascii.decode(bytes.sublist(12, 16));
  if (chunkType != 'IHDR') {
    _fail('Google Play store icon has no PNG IHDR.');
  }
  int uint32(int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
  final width = uint32(16);
  final height = uint32(20);
  final colorType = bytes[25];
  if (width != 512 || height != 512) {
    _fail('Google Play store icon must be exactly 512 x 512 pixels.');
  }
  if (colorType == 4 || colorType == 6) {
    _fail('Google Play store icon must not contain an alpha channel.');
  }
}

void _validateGooglePlayFeatureGraphic(Directory root, String relativePath) {
  final file = File('${root.path}/$relativePath');
  if (!file.existsSync()) {
    _fail('Missing Google Play feature graphic: $relativePath');
  }
  final bytes = file.readAsBytesSync();
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 33 ||
      !List<int>.generate(8, (index) => bytes[index])
          .asMap()
          .entries
          .every((entry) => entry.value == signature[entry.key])) {
    _fail('Google Play feature graphic must be a valid PNG.');
  }
  if (ascii.decode(bytes.sublist(12, 16)) != 'IHDR') {
    _fail('Google Play feature graphic has no PNG IHDR.');
  }
  int uint32(int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
  final width = uint32(16);
  final height = uint32(20);
  final bitDepth = bytes[24];
  final colorType = bytes[25];
  if (width != 1024 || height != 500) {
    _fail('Google Play feature graphic must be exactly 1024 x 500 pixels.');
  }
  if (bitDepth != 8 || colorType != 2) {
    _fail(
        'Google Play feature graphic must be a 24-bit RGB PNG without alpha.');
  }
}

Map<String, dynamic> _map(Object? value, String field) {
  if (value is! Map) _fail('$field must be an object.');
  return value.cast<String, dynamic>();
}

String _string(Map<String, dynamic> map, String field) {
  final value = map[field];
  if (value is! String || value.trim().isEmpty) {
    _fail('$field must be a non-empty string.');
  }
  return value.trim();
}

int _runes(String value) => value.runes.length;

void _maxRunes(String label, String value, int maximum) {
  final length = _runes(value);
  if (length > maximum) {
    _fail('$label has $length characters; maximum is $maximum.');
  }
}

void _maxUtf8Bytes(String label, String value, int maximum) {
  final length = utf8.encode(value).length;
  if (length > maximum) {
    _fail('$label has $length UTF-8 bytes; maximum is $maximum.');
  }
}

void _requireHttps(String label, Object? raw) {
  if (raw is! String) _fail('$label must be a URL string.');
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    _fail('$label must be an absolute HTTPS URL.');
  }
}

void _rejectPublicCopy(String label, String value) {
  final lower = value.toLowerCase();
  const forbidden = <String>[
    '100 % sicher',
    '100% sicher',
    'garantiert sicher',
    'vollständig versichert',
    'marktführer',
    'zertifiziert sicher',
    'airbnb',
    'staging',
    'testzahlung',
    'debug',
  ];
  for (final phrase in forbidden) {
    if (lower.contains(phrase)) {
      _fail('$label contains forbidden or non-public claim: "$phrase".');
    }
  }
}

String _pubspecVersion(Directory root) {
  final pubspec = File('${root.path}/pubspec.yaml').readAsLinesSync();
  final line = pubspec.firstWhere(
    (value) => value.startsWith('version:'),
    orElse: () => _fail('pubspec.yaml has no version field.'),
  );
  return line.substring('version:'.length).trim();
}

void main(List<String> arguments) {
  var requireSubmittable = false;
  String? manifestPath;
  for (var index = 0; index < arguments.length; index += 1) {
    final value = arguments[index];
    if (value == '--require-submittable') {
      requireSubmittable = true;
    } else if (value == '--manifest') {
      if (index + 1 >= arguments.length) {
        _fail('--manifest requires a path.');
      }
      manifestPath = arguments[index + 1];
      index += 1;
    } else {
      _fail('Unknown argument: $value');
    }
  }

  final scriptFile = File.fromUri(Platform.script).absolute;
  final root = scriptFile.parent.parent;
  final manifestFile = manifestPath == null
      ? File('${root.path}/store/submission.json')
      : File(manifestPath).absolute;
  if (!manifestFile.existsSync())
    _fail('Store submission manifest is missing.');

  final decoded = jsonDecode(manifestFile.readAsStringSync());
  final manifest = _map(decoded, 'store/submission.json');
  if (manifest['schemaVersion'] != 1) _fail('Unsupported schemaVersion.');

  final identity = _map(manifest['identity'], 'identity');
  final product = _map(manifest['product'], 'product');
  final urls = _map(manifest['publicUrls'], 'publicUrls');
  final gates = _map(manifest['blockingGates'], 'blockingGates');
  final metadataFiles = _map(manifest['metadataFiles'], 'metadataFiles');
  final googleFiles =
      _map(metadataFiles['googlePlay'], 'metadataFiles.googlePlay');
  final appleFiles = _map(metadataFiles['apple'], 'metadataFiles.apple');
  final assets = _map(manifest['assets'], 'assets');
  final googleAssets = _map(assets['googlePlay'], 'assets.googlePlay');

  const requiredBlockingGates = <String>{
    'legalProviderIdentity',
    'copyrightOwner',
    'termsAndUserContentRules',
    'firebaseTermsAcceptedByOwner',
    'firebaseFcmAndApns',
    'googlePlayAccountAndFee',
    'appleAccountXcodeAndSigning',
    'reviewAccounts',
    'realAndroidAndIosDevices',
    'finalBinaryPrivacyScan',
    'closedStoreAndAccessibilityMatrix',
  };
  if (gates.length != requiredBlockingGates.length ||
      !requiredBlockingGates.every(gates.containsKey)) {
    _fail(
        'blockingGates must contain exactly the required Store release gates.');
  }

  const expectedId = 'com.shareittoo.app';
  if (_string(identity, 'applicationId') != expectedId ||
      _string(identity, 'bundleId') != expectedId) {
    _fail('Android and iOS store identifiers must both be $expectedId.');
  }

  final pubspecVersion = _pubspecVersion(root);
  final match =
      RegExp(r'^(\d+\.\d+\.\d+)\+(\d{10})$').firstMatch(pubspecVersion);
  if (match == null) _fail('pubspec version must use semantic+YYYYMMDDNN.');
  if (match.group(1) != _string(identity, 'versionName')) {
    _fail('Store versionName does not match pubspec.yaml.');
  }
  final currentBuild = BigInt.parse(match.group(2)!);
  final minimumStoreBuild =
      BigInt.parse(_string(identity, 'minimumStoreBuildNumber'));
  if (minimumStoreBuild < BigInt.from(2026080903)) {
    _fail('minimumStoreBuildNumber must be at least 2026080903.');
  }

  if (_string(identity, 'releaseChannel') != 'internal') {
    _fail('B11 store metadata must remain on the internal release channel.');
  }
  if (_string(identity, 'apiBaseUrl') !=
      'https://staging.shareittoo.com/api/v1') {
    _fail('B11 store metadata must target the isolated staging API.');
  }

  if (product['physicalGoodsRental'] != true ||
      product['minimumUserAge'] != 18 ||
      product['designedForChildren'] != false ||
      product['containsAds'] != false ||
      product['advertisingTracking'] != false ||
      product['firebaseAnalytics'] != false) {
    _fail('Product truth flags do not match the approved B11 scope.');
  }

  final googleTitle = _readText(root, _string(googleFiles, 'title'));
  final googleShort = _readText(root, _string(googleFiles, 'shortDescription'));
  final googleFull = _readText(root, _string(googleFiles, 'fullDescription'));
  final googleNotes =
      _readText(root, _string(googleFiles, 'internalReleaseNotes'));
  final googleScreenshotAltTexts =
      _readJsonList(root, _string(googleFiles, 'screenshotAltTexts'));
  final appleName = _readText(root, _string(appleFiles, 'name'));
  final appleSubtitle = _readText(root, _string(appleFiles, 'subtitle'));
  final applePromo = _readText(root, _string(appleFiles, 'promotionalText'));
  final appleDescription = _readText(root, _string(appleFiles, 'description'));
  final appleKeywords = _readText(root, _string(appleFiles, 'keywords'));
  final appleReviewNotes =
      _readText(root, _string(appleFiles, 'reviewNotesTemplate'));
  _validateGooglePlayIcon(root, _string(googleAssets, 'storeIcon'));
  _validateGooglePlayFeatureGraphic(
      root, _string(googleAssets, 'featureGraphic'));
  final phoneScreenshots = googleAssets['phoneScreenshots'];
  if (phoneScreenshots is! List || phoneScreenshots.isNotEmpty) {
    _fail('Google Play phone screenshots must remain empty until validated.');
  }

  _maxRunes('Google title', googleTitle, 30);
  _maxRunes('Google short description', googleShort, 80);
  _maxRunes('Google full description', googleFull, 4000);
  _maxRunes('Apple name', appleName, 30);
  _maxRunes('Apple subtitle', appleSubtitle, 30);
  _maxRunes('Apple promotional text', applePromo, 170);
  _maxRunes('Apple description', appleDescription, 4000);
  _maxUtf8Bytes('Apple keywords', appleKeywords, 100);
  _maxUtf8Bytes('Apple review notes', appleReviewNotes, 4000);

  const expectedScreenshotIds = <String>{
    'feed',
    'search',
    'listing-detail',
    'create-listing',
    'booking-request',
    'booking-chat',
    'handover-return',
    'trust-controls',
  };
  if (googleScreenshotAltTexts.length != expectedScreenshotIds.length) {
    _fail('Google screenshot alt texts must contain exactly eight scenes.');
  }
  final observedScreenshotIds = <String>{};
  for (final raw in googleScreenshotAltTexts) {
    final entry = _map(raw, 'Google screenshot alt text entry');
    final id = _string(entry, 'id');
    final altText = _string(entry, 'altText');
    if (!expectedScreenshotIds.contains(id) || !observedScreenshotIds.add(id)) {
      _fail('Google screenshot alt text ids must be unique approved scenes.');
    }
    _maxRunes('Google screenshot alt text $id', altText, 140);
    _rejectPublicCopy('Google screenshot alt text $id', altText);
  }

  if (googleTitle != appleName || googleTitle != 'ShareItToo') {
    _fail('Google and Apple names must use the ShareItToo product name.');
  }
  if (appleKeywords.toLowerCase().contains('shareittoo')) {
    _fail('Apple keywords must not duplicate the app name.');
  }

  for (final entry in <String, String>{
    'Google title': googleTitle,
    'Google short description': googleShort,
    'Google full description': googleFull,
    'Apple name': appleName,
    'Apple subtitle': appleSubtitle,
    'Apple promotional text': applePromo,
    'Apple description': appleDescription,
  }.entries) {
    _rejectPublicCopy(entry.key, entry.value);
  }

  if (!googleNotes.toLowerCase().contains('staging') ||
      !googleNotes.toLowerCase().contains('testzahlung')) {
    _fail(
        'Internal Google release notes must state staging and test payments.');
  }
  if (!appleReviewNotes.toLowerCase().contains('physical items') ||
      !appleReviewNotes.toLowerCase().contains('test payments') ||
      !appleReviewNotes.toLowerCase().contains('no ads') ||
      !appleReviewNotes.toLowerCase().contains('no credentials')) {
    _fail('Apple review notes omit a required B11 truth boundary.');
  }

  final sourceDocuments = manifest['sourceDocuments'];
  if (sourceDocuments is! List || sourceDocuments.isEmpty) {
    _fail('sourceDocuments must contain the B11 evidence documents.');
  }
  for (final value in sourceDocuments) {
    if (value is! String || !File('${root.path}/$value').existsSync()) {
      _fail('Missing source document: $value');
    }
  }

  final marketing = _map(urls['marketing'], 'publicUrls.marketing');
  if (marketing['status'] != 'verified') {
    _fail('Marketing URL must remain verified.');
  }
  _requireHttps('publicUrls.marketing.url', marketing['url']);

  const requiredPublicUrls = <String>['support', 'privacy', 'accountDeletion'];
  const expectedPublicUrls = <String, String>{
    'support': 'https://shareittoo.com/support',
    'privacy': 'https://shareittoo.com/privacy',
    'accountDeletion': 'https://shareittoo.com/account-deletion',
  };
  final openUrlGates = <String>[];
  for (final key in requiredPublicUrls) {
    final value = _map(urls[key], 'publicUrls.$key');
    final status = value['status'];
    if (status == 'verified') {
      _requireHttps('publicUrls.$key.url', value['url']);
    } else if (status == 'draft') {
      _requireHttps('publicUrls.$key.url', value['url']);
      openUrlGates.add(key);
    } else if (status == 'open' && value['url'] == null) {
      openUrlGates.add(key);
    } else {
      _fail(
          'publicUrls.$key must be verified/draft with HTTPS or open with null URL.');
    }
    if (value['url'] != null && value['url'] != expectedPublicUrls[key]) {
      _fail('publicUrls.$key.url must be ${expectedPublicUrls[key]}.');
    }
  }
  final deletion = _map(urls['accountDeletion'], 'publicUrls.accountDeletion');
  _requireHttps(
    'publicUrls.accountDeletion.stagingEvidenceUrl',
    deletion['stagingEvidenceUrl'],
  );

  final openGates = <String>[];
  for (final entry in gates.entries) {
    if (entry.value == 'open') {
      openGates.add(entry.key);
    } else if (entry.value != 'closed') {
      _fail('Gate ${entry.key} must be open or closed.');
    }
  }

  final submissionAllowed = manifest['submissionAllowed'] == true;
  final state = manifest['state'];
  if (state != 'draft' && state != 'ready') {
    _fail('state must be draft or ready.');
  }

  if (submissionAllowed || state == 'ready') {
    if (!submissionAllowed || state != 'ready') {
      _fail('ready and submissionAllowed must change together.');
    }
    if (openUrlGates.isNotEmpty || openGates.isNotEmpty) {
      _fail('A submittable manifest cannot contain open URLs or gates.');
    }
    if (currentBuild < minimumStoreBuild) {
      _fail('Current pubspec build is below the minimum store build.');
    }
  } else if (state != 'draft') {
    _fail('A non-submittable manifest must remain in draft state.');
  }

  if (requireSubmittable && !submissionAllowed) {
    _fail(
      'Store submission remains blocked: URLs=${openUrlGates.join(',')}; '
      'gates=${openGates.join(',')}; currentBuild=$currentBuild; '
      'minimumBuild=$minimumStoreBuild.',
    );
  }

  stdout.writeln(
    'Store metadata valid: state=$state, submissionAllowed=$submissionAllowed, '
    'currentBuild=$currentBuild, minimumStoreBuild=$minimumStoreBuild, '
    'openUrls=${openUrlGates.length}, openGates=${openGates.length}.',
  );
}
